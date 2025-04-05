//
//  File.swift
//  WMScanner
//
//  Created by Suman Kumar on 4/5/25.
//

import Foundation
import Combine

final class VKScanViewModel: ObservableObject {
    @Published var currentScannedBarcodes: String = ""
    var scannedBarcodes: Set<ScanResult> = []
    var cancellables = Set<AnyCancellable>()
    let scannedCodesPub =  PassthroughSubject<[String], Never>()
    let scannedCodesForSessionPub = PassthroughSubject<[ScanResult], Never>()
    
    func publishAllScanedCodes() {
        scannedCodesForSessionPub.send(Array(scannedBarcodes))
    }
}
