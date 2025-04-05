//
//  AVScannerController.swift
//  WMScanner
//
//  Created by Suman Kumar on 4/5/25.
//

import UIKit
import AVFoundation
import Combine

class AVScannerController: UIViewController {

    lazy var cameraScanView: CameraView = {
        CameraView.init(frame: self.view.frame)
    }()
    
    private enum VideoSessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    lazy var zoomSlider: UISlider = {
        let slider = UISlider()
        slider.tintColor = .white
        slider.addTarget(self, action: #selector(zoomCamera(with:)), for: .valueChanged)
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    lazy var bottomStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    lazy var scannedBarCodeLbl: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.text = ""
        label.textAlignment = .center
        label.numberOfLines = 4
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var selectTypesButton: UIButton = {
        let button = UIButton()
        button.setTitle("Select Barcode Types", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.addTarget(self, action: #selector(presentTypeSelector), for: .touchUpInside)
        return button
    }()
    
    lazy var torchButton: UIButton = {
        let button = UIButton()
        button.setTitle("Torch", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
        return button
    }()
    
    private var cancellable : AnyCancellable?
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "session queue")
    private var setupResult: VideoSessionSetupResult = .success
    private var isSessionActive = false
    var videoDeviceInput: AVCaptureDeviceInput!
    private var isSessionRunning = false

    private let metadataOutput = AVCaptureMetadataOutput()
    private let metadataObjectsQueue = DispatchQueue(label: "metadata objects queue", attributes: [], target: nil)
    
    private var keyValueObservations = [NSKeyValueObservation]()
    
    private class MetadataObjectLayer: CAShapeLayer {
        var metadataObject: AVMetadataObject?
    }
    
    private let drawingSemaphore = DispatchSemaphore(value: 1)
    private var metadataObjectOverlayLayers = [MetadataObjectLayer]()
    
    let viewModel: AVScannerViewModel
    
    init(_ viewModel: AVScannerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(cameraScanView)
        cameraScanView.session = session
        self.checkCameraAccess()
        self.configureScanScreen()
        self.configureBottomStack()
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.title = "Scanner"
        self.navigationController?.navigationBar.tintColor = .white
        self.navigationController?.presentationController?.delegate = self

        sessionQueue.async {
            switch self.setupResult {
            case .success:
                self.addObservers()
                self.session.startRunning()
                self.isSessionActive = self.session.isRunning
            
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivatySetting = "Scanner doesn't have permission to use the camera, please change privacy settings"
                    let alertController = UIAlertController(title: "Scanner", message: changePrivatySetting, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                    alertController.addAction(UIAlertAction(title: "Settings", style: .default, handler: { _ in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Unable to capture media. Something went wrong. Please try again later."
                    let alertController = UIAlertController(title: "Scanner", message: alertMsg, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }
        super.viewWillDisappear(animated)
    }
    
    private func configureScanScreen() {
        self.view.addSubview(zoomSlider)
        self.view.addSubview(scannedBarCodeLbl)
        NSLayoutConstraint.activate([
            zoomSlider.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20.0),
            zoomSlider.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20.0),
            zoomSlider.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -80.0),
            scannedBarCodeLbl.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            scannedBarCodeLbl.topAnchor.constraint(equalTo: self.view.topAnchor, constant: 60.0),
        ])
    }
    
    private func configureBottomStack() {
        bottomStack.addArrangedSubview(selectTypesButton)
        bottomStack.addArrangedSubview(torchButton)
        self.view.addSubview(bottomStack)
        NSLayoutConstraint.activate([
            bottomStack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 20.0),
            bottomStack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -20.0),
            bottomStack.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: -20.0)
        ])
    }
    
    @objc private func zoomCamera(with zoomSlider: UISlider) {
        do {
            try videoDeviceInput.device.lockForConfiguration()
            
            videoDeviceInput.device.videoZoomFactor = max(CGFloat(zoomSlider.value), 1.0)
            videoDeviceInput.device.unlockForConfiguration()
        } catch {
            print("Could not lock for configuration: \(error)")
        }
    }
    
    @objc private func toggleTorch() {
        do {
            try videoDeviceInput.device.lockForConfiguration()
            
            if videoDeviceInput.device.hasTorch {
                videoDeviceInput.device.torchMode = videoDeviceInput.device.isTorchActive ? .off : .on
            }
            videoDeviceInput.device.unlockForConfiguration()
        } catch {
            print("Could not toggle torch: \(error)")
        }
    }
    
    @objc private func presentTypeSelector() {
        viewModel.presentTypeSelector()
    }
    
    private func addObservers() {
        var keyValueObservation: NSKeyValueObservation
        
        keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
            guard let isSessionRunning = change.newValue else { return }

            DispatchQueue.main.async {
                self.selectTypesButton.isEnabled = isSessionRunning
                self.zoomSlider.isEnabled = isSessionRunning
                
                if !isSessionRunning {
                    self.removeBarcodeOverlayLayers()
                }
                
                if isSessionRunning {
                    self.cameraScanView.setFocusRegion(self.cameraScanView.regionOfInterest)
                }
            }
        }
        keyValueObservations.append(keyValueObservation)
    
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: session)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVCaptureSessionRuntimeError, object: session)
        
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
    }
      
    private var removeLayersTimer: Timer?

    @objc private func removeBarcodeOverlayLayers() {
        for sublayer in metadataObjectOverlayLayers {
            sublayer.removeFromSuperlayer()
        }
        metadataObjectOverlayLayers = []
        
        removeLayersTimer?.invalidate()
        removeLayersTimer = nil
    }
    
    private func addBarcodeScannedLayer(_ metadataObjectOverlayLayers: [MetadataObjectLayer], scannedCodes: [String]) {
        // Add the metadata object overlays as sublayers of the video preview layer. We disable actions to allow for fast drawing.
        print("codes ", scannedCodes)
        self.scannedBarCodeLbl.text = scannedCodes.joined(separator: "\n")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for metadataObjectOverlayLayer in metadataObjectOverlayLayers {
            cameraScanView.videoPreviewLayer.addSublayer(metadataObjectOverlayLayer)
        }
        CATransaction.commit()
        
        // Save the new metadata object overlays.
        self.metadataObjectOverlayLayers = metadataObjectOverlayLayers
        
        removeLayersTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(removeBarcodeOverlayLayers), userInfo: nil, repeats: false)
    }
    
    func checkCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
    
        default:
            setupResult = .notAuthorized
        }
    }
    
    func configureSession() {
        guard setupResult == .success else { return }
        session.beginConfiguration()
        self.viewModel.scannedCodes.removeAll()
        do {
            var defaultVideoDevice: AVCaptureDevice? = nil
            
            // Choose the back wide angle camera if available, otherwise default to the front wide angle camera.
            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                defaultVideoDevice = backCameraDevice
            }
            
            guard let videoDevice = defaultVideoDevice else {
                print("Could not get video device")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                DispatchQueue.main.async {
                    self.cameraScanView.videoPreviewLayer.connection!.videoOrientation =
                        .portrait
                }
            } else {
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        } catch {
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        
        // Add metadata output.
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            // Set this view controller as the delegate for metadata objects.
            metadataOutput.setMetadataObjectsDelegate(self, queue: metadataObjectsQueue)
            metadataOutput.metadataObjectTypes = viewModel.selectedBarcodeTypes
            
            let formatDimensions = CMVideoFormatDescriptionGetDimensions(self.videoDeviceInput.device.activeFormat.formatDescription)
            let rectOfInterestWidth = Double(formatDimensions.height) / Double(formatDimensions.width)
            let xCoordinate = (1.0 - rectOfInterestWidth) / 2.0
            let initialRectOfInterest = CGRect(x: xCoordinate, y: 0.0, width: rectOfInterestWidth, height: 1.0)
            metadataOutput.rectOfInterest = initialRectOfInterest

            DispatchQueue.main.async {
                let initialRegionOfInterest = self.cameraScanView.videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: initialRectOfInterest)
                self.cameraScanView.setFocusRegion(initialRegionOfInterest)
                self.session.sessionPreset = .high
                self.zoomSlider.maximumValue = Float(min(self.videoDeviceInput.device.activeFormat.videoMaxZoomFactor, CGFloat(8.0)))
                self.zoomSlider.value = Float(self.videoDeviceInput.device.videoZoomFactor)
            }
            
            self.setSubscriberForTargetTypes()
        } else {
            print("Could not add metadata output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.commitConfiguration()
    }
    
    func setSubscriberForTargetTypes() {
        cancellable = viewModel.targetBarcodeTypesPub.sink { types in
            self.metadataOutput.metadataObjectTypes = types
        }
    }
    
    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        print("Capture session runtime error: \(error)")
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
     }
}

extension AVScannerController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if drawingSemaphore.wait(timeout: .now()) == .success {
            DispatchQueue.main.async {
                self.removeBarcodeOverlayLayers()
                var metadataObjectOverlayLayers = [MetadataObjectLayer]()
                var currentScanned: [String] = []
                for metadataObject in metadataObjects {
                    let (metadataObjectOverlayLayer, scanned) = self.createMetadataObjectOverlayWithMetadataObject(metadataObject)
                    metadataObjectOverlayLayers.append(metadataObjectOverlayLayer)
                    currentScanned.append(scanned ?? "")
                }
                self.addBarcodeScannedLayer(metadataObjectOverlayLayers, scannedCodes: currentScanned.filter({ $0 != ""}))
                self.drawingSemaphore.signal()
            }
        }
    }
    
    private func barcodeOverlayPathWithCorners(_ corners: [CGPoint]) -> CGMutablePath {
        let path = CGMutablePath()
        if let corner = corners.first {
            path.move(to: corner, transform: .identity)
            for corner in corners[1..<corners.count] {
                path.addLine(to: corner)
            }
            path.closeSubpath()
        }
        return path
    }
    
    private func createMetadataObjectOverlayWithMetadataObject(_ metadataObject: AVMetadataObject) -> (MetadataObjectLayer, String?) {
        // Transform the metadata object so the bounds are updated to reflect those of the video preview layer.
        let transformedMetadataObject = cameraScanView.videoPreviewLayer.transformedMetadataObject(for: metadataObject)
        
        // Create the initial metadata object overlay layer that can be used for either machine readable codes or faces.
        let metadataObjectOverlayLayer = MetadataObjectLayer()
        metadataObjectOverlayLayer.metadataObject = transformedMetadataObject
        metadataObjectOverlayLayer.lineJoin = .round
        metadataObjectOverlayLayer.lineWidth = 2.0
        metadataObjectOverlayLayer.strokeColor = UIColor.green.withAlphaComponent(0.7).cgColor
        metadataObjectOverlayLayer.fillColor = UIColor.green.withAlphaComponent(0.3).cgColor
        var scannedBarcode: String?
        if let barcodeMetadataObject = transformedMetadataObject as? AVMetadataMachineReadableCodeObject {
            let barcodeOverlayPath = barcodeOverlayPathWithCorners(barcodeMetadataObject.corners)
            metadataObjectOverlayLayer.path = barcodeOverlayPath
            if let scanned = barcodeMetadataObject.stringValue {
                scannedBarcode = scanned
                let result = ScanResult(scannedBarcode: scanned, barcodeType: barcodeMetadataObject.type.rawValue)
                if !viewModel.scannedCodes.contains(result) {
                    viewModel.scannedCodes.append(result)
                }
            }
        }
        return (metadataObjectOverlayLayer, scannedBarcode)
    }
}

extension AVScannerController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        viewModel.sendScannedCodes()
    }
}
