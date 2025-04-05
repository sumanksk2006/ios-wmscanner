// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import UIKit
import AVFoundation

public enum ScannerType {
    case avScan
    case visionKitScan
}

public protocol ScanManaging {
    func scanForBarcodes(_ rootVC: UIViewController, type: ScannerType) async throws -> [ScanResult]
}

protocol ScannerCoordinating {
    var continuationResult: CheckedContinuation<[ScanResult], any Error> { get set }
    func startScan(_ rootVC: UIViewController)
}

public struct ScanResult: Hashable {
    public var scannedBarcode: String
    public var barcodeType: String = ""
}

public final class ScanManager: ScanManaging {
    public init() { }
    
    public func scanForBarcodes(_ rootVC: UIViewController, type: ScannerType) async throws -> [ScanResult] {
        try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<[ScanResult], Error>) in
            DispatchQueue.main.async {
                self.getScanner(type, with: continuation).startScan(rootVC)
            }
        })
    }
    
    func getScanner(_ type: ScannerType, with continuation: CheckedContinuation<[ScanResult], any Error>) -> ScannerCoordinating {
        switch type {
        case .avScan:
            return AVScannerCoordinator(continuation)
        case .visionKitScan:
            return VKScanCoordinator(continuation)
        }
    }
}
