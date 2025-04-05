//
//  BarcodeTypeSelectionView.swift
//  WMScanner
//
//  Created by Suman Kumar on 4/5/25.
//

import SwiftUI

struct BarcodeTypeSelectionView: View {
    @State var viewModel: BarcodeTypeSelectVM
    
    var body: some View {
        List {
            ForEach($viewModel.barcodeTypes) { $barcodeType in
                HStack {
                    Toggle(isOn: $barcodeType.selected) {
                        Text(barcodeType.type)
                    }
                    .toggleStyle(.switch)
                }
                
            }
        }
        .onDisappear {
            viewModel.selectedTypesPublisher.send(viewModel.barcodeTypes.filter({ $0.selected }))
        }
        
    }
}

#Preview {
    BarcodeTypeSelectionView(viewModel: BarcodeTypeSelectVM([
        BarcodeType(type: "UTC", selected: false)
    ]))
}
