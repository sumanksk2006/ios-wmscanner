//
//  File.swift
//  WMScanner
//
//  Created by Suman Kumar on 4/5/25.
//

import Combine
import Foundation
import UIKit
import SwiftUI

class AVScannerCoordinator: ScannerCoordinating {
    var continuationResult: CheckedContinuation<[ScanResult], any Error>
    var navVC: UINavigationController?
    var cancellables = Set<AnyCancellable>()
    
    init(_ continuationResult: CheckedContinuation<[ScanResult], any Error>) {
        self.continuationResult = continuationResult
    }
    
    lazy var avScannerViewModel: AVScannerViewModel = {
        let avViewModel = AVScannerViewModel()
        
        avViewModel.scannedBarCodesPub.sink { result in
            self.continuationResult.resume(returning: result)
        }.store(in: &cancellables)
        
        avViewModel.scanTypesSelectionPub.sink { barcodeTypes in
            self.presentBarcodeTypesSelector(types: barcodeTypes)
        }.store(in: &cancellables)
        
        return avViewModel
    }()
    
    func startScan(_ rootVC: UIViewController) {
        let scanVC = AVScannerController(avScannerViewModel)
        scanVC.view.frame = UIScreen.main.bounds
        scanVC.view.backgroundColor = .black
        navVC = UINavigationController(rootViewController: scanVC)
        rootVC.present(navVC!, animated: true)
    }
    
    func presentBarcodeTypesSelector(types: [BarcodeType]) {
        let selectorVM = BarcodeTypeSelectVM(types)
        selectorVM.selectedTypesPublisher
            .sink { types in
                self.avScannerViewModel.updateBarcodeTypes(types)
            }.store(in: &cancellables)

        let hostingVC = UIHostingController(rootView: BarcodeTypeSelectionView(viewModel: selectorVM))
        navVC?.present(hostingVC, animated: true)
    }
}
