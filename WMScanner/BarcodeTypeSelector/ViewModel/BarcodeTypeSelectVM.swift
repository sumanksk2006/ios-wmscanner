//
//  BarcodeTypeSelectVM.swift
//  WMScanner
//
//  Created by Suman Kumar on 4/5/25.
//

import Foundation
import Combine

struct BarcodeType: Identifiable {
    let type: String
    var selected: Bool = true
    var id: Int {
        type.hashValue
    }
}

final class BarcodeTypeSelectVM: ObservableObject {
    @Published var barcodeTypes: [BarcodeType]
    let selectedTypesPublisher = PassthroughSubject<[BarcodeType], Never>()

    init(_ barcodeTypes: [BarcodeType]) {
        self.barcodeTypes = barcodeTypes
    }
    
}
