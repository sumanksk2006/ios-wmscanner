//
//  AVScannerViewModel.swift
//  WMScanner
//
//  Created by Suman Kumar on 4/5/25.
//

import Foundation
import AVFoundation
import Combine

final class AVScannerViewModel: NSObject {
    var scannedCodes: [ScanResult] = []
    let scannedBarCodesPub = PassthroughSubject<[ScanResult], Never>()
    let scanTypesSelectionPub = PassthroughSubject<[BarcodeType], Never>()
    let targetBarcodeTypesPub = PassthroughSubject<[AVMetadataObject.ObjectType], Never>()

    var availableBarcodeTypes: [AVMetadataObject.ObjectType] {
        [
            .ean8,
            .code39,
            .upce,
            .code39Mod43,
            .ean13,
            .code93,
            .code128,
            .pdf417,
            .qr,
            .aztec,
            .interleaved2of5,
            .itf14,
            .dataMatrix,
            .codabar,
            .gs1DataBar,
            .gs1DataBarLimited,
            .gs1DataBarExpanded,
            .microQR,
            .microPDF417
        ]
    }
    var selectedBarcodeTypes: [AVMetadataObject.ObjectType] = [] {
        didSet {
            targetBarcodeTypesPub.send(selectedBarcodeTypes)
        }
    }
    
    override init() {
        super.init()
        self.selectedBarcodeTypes = self.availableBarcodeTypes
    }
    
    func sendScannedCodes() {
        self.scannedBarCodesPub.send(scannedCodes)
    }
    
    func presentTypeSelector() {
        let barcodeTypes: [BarcodeType] = self.availableBarcodeTypes.map({
            let isSelected = self.selectedBarcodeTypes.contains($0)
            return BarcodeType(type: $0.rawValue, selected: isSelected)
        })
        self.scanTypesSelectionPub.send(barcodeTypes)
    }
    
    func updateBarcodeTypes(_ selectedTypes: [BarcodeType]) {
        selectedBarcodeTypes = selectedTypes.compactMap ({
            AVMetadataObject.ObjectType(rawValue: $0.type)
        })
        targetBarcodeTypesPub.send(selectedBarcodeTypes)
    }
}
