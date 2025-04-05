//
//  SwiftUIView.swift
//  WMScanner
//
//  Created by Suman Kumar on 4/5/25.
//

import SwiftUI
import VisionKit
import Combine

struct VisionKitScannerView: View {
    @ObservedObject var viewModel: VKScanViewModel
    var cancellable: AnyCancellable?
    
    var body: some View {
        ZStack {
            VKDataScanner(viewModel.scannedCodesPub)
            
            VStack {
                Spacer()
                if $viewModel.currentScannedBarcodes.wrappedValue != "" {
                    Text($viewModel.currentScannedBarcodes.wrappedValue)
                        .padding(.all, 8)
                        .cornerRadius(4)
                        .foregroundColor(.white)
                        .font(Font.system(size: 17, weight: .bold))
                        .background(.black.opacity(0.6))
                }
            }
            .padding(.bottom, 80)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            viewModel.scannedCodesPub.sink { codes in
                viewModel.currentScannedBarcodes = codes.joined(separator: "\n")
                viewModel.scannedBarcodes.formUnion(codes.map{ ScanResult(scannedBarcode: $0) })
            }
            .store(in: &viewModel.cancellables)
        }
        .onDisappear {
            viewModel.publishAllScanedCodes()
        }
        
    }
}

struct VKDataScanner: UIViewControllerRepresentable {
    let scanCodePublisher: PassthroughSubject<[String], Never>
    
    init(_ scanCodePublisher: PassthroughSubject<[String], Never>) {
        self.scanCodePublisher = scanCodePublisher
    }
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        // Check if scanning is available
        guard DataScannerViewController.isSupported,
              DataScannerViewController.isAvailable else {
            fatalError("DataScannerViewController is not supported on this device")
        }
        
        // Configure the scanner
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        
        scanner.delegate = context.coordinator
        scanner.view.tintColor = .green
        
        // Start scanning
        try? scanner.startScanning()
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
    
    func makeCoordinator() -> VisionKitScanCoordinator {
        VisionKitScanCoordinator(scanCodePublisher)
    }
}

class VisionKitScanCoordinator: NSObject, DataScannerViewControllerDelegate {
    let scanCodePublisher: PassthroughSubject<[String], Never>

    init(_ scanCodePublisher: PassthroughSubject<[String], Never>) {
        self.scanCodePublisher = scanCodePublisher
    }
    
    func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
//        self.scanCodePublisher.send([])
    }
    
    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        var scannedCodes: [String] = []
        for item in addedItems {
            switch item {
            case .barcode(let code):
                if let barcodeValue = code.payloadStringValue {
                    scannedCodes.append(barcodeValue)
                }
            default:
                break
            }
        }
        self.scanCodePublisher.send(scannedCodes)
    }
}
