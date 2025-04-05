//
//  CameraView.swift
//  WMScanner
//
//  Created by Suman Kumar on 4/5/25.
//

import UIKit
import AVFoundation

final class CameraView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        drawOverlay()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        drawOverlay()
    }
    
    private let overlay = CAShapeLayer()
    private let focusOutline = CAShapeLayer()

    @objc private(set) dynamic var regionOfInterest = CGRect.null

    private func drawOverlay() {
        overlay.fillRule = .evenOdd
        overlay.fillColor = UIColor.black.cgColor
        overlay.opacity = 0.6
        layer.addSublayer(overlay)
        
        focusOutline.path = UIBezierPath(rect: regionOfInterest).cgPath
        focusOutline.fillColor = UIColor.clear.cgColor
        focusOutline.strokeColor = UIColor.yellow.cgColor
        layer.addSublayer(focusOutline)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let path = UIBezierPath(rect: CGRect(x: 0, y: 60, width: frame.size.width, height: frame.size.height))
        path.append(UIBezierPath(rect: regionOfInterest))
        path.usesEvenOddFillRule = true
        overlay.path = path.cgPath
        
        focusOutline.path = CGPath(rect: regionOfInterest, transform: nil)

        CATransaction.commit()
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    func setFocusRegion(_ region: CGRect) {
        let videoPreviewRect = videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1)).standardized
        let visibleVideoPreviewRect = videoPreviewRect.intersection(frame)
        var focusRegion = region.standardized
        
        var xOffset: CGFloat = 0
        var yOffset: CGFloat = 0
        
        if !visibleVideoPreviewRect.contains(focusRegion.origin) {
            xOffset = max(visibleVideoPreviewRect.minX - focusRegion.minX, CGFloat(0))
            yOffset = max(visibleVideoPreviewRect.minY - focusRegion.minY, CGFloat(0))
        }
        
        if !visibleVideoPreviewRect.contains(CGPoint(x: visibleVideoPreviewRect.maxX, y: visibleVideoPreviewRect.maxY)) {
            xOffset = min(visibleVideoPreviewRect.maxX - focusRegion.maxX, xOffset)
            yOffset = min(visibleVideoPreviewRect.maxY - focusRegion.maxY, yOffset)
        }
        
        focusRegion = focusRegion.offsetBy(dx: xOffset, dy: yOffset)
        focusRegion = visibleVideoPreviewRect.intersection(focusRegion)
        focusRegion.origin.x = 10.0
        focusRegion.size.width -= 10.0
        focusRegion.size.height -= 60.0
        self.regionOfInterest = focusRegion
        setNeedsLayout()
    }
}
