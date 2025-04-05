//
//  VKScanCoordinator.swift
//  WMScanner
//
//  Created by Suman Kumar on 4/5/25.
//

import Foundation
import VisionKit
import UIKit
import SwiftUI
import Combine

class VKScanCoordinator: ScannerCoordinating {
    var continuationResult: CheckedContinuation<[ScanResult], any Error>
    var navVC: UINavigationController?
    var cancellables = Set<AnyCancellable>()
    
    init(_ continuationResult: CheckedContinuation<[ScanResult], any Error>) {
        self.continuationResult = continuationResult
    }
    
    lazy var viewModel: VKScanViewModel = {
        let vm = VKScanViewModel()
        vm.scannedCodesForSessionPub.sink { scanned in
            self.continuationResult.resume(returning: scanned)
        }.store(in: &cancellables)
        
        return vm
    }()
    
    func startScan(_ rootVC: UIViewController) {
        let scanner = UIHostingController(rootView: VisionKitScannerView(viewModel: viewModel))
        navVC = UINavigationController(rootViewController: scanner)
        rootVC.present(navVC!, animated: true)
    }
}
