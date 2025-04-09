# ios-wmscanner
WMScanner implements 2 types of native camera scanners

  - AVFoundation Scanner
  - VisionKit Scanner (available from iOS 16+)

Code is implemented in MVVM-C with protocol design pattern and Combine

```swift
public protocol ScanManaging {
    func scanForBarcodes(_ rootVC: UIViewController, type: ScannerType) async throws -> [ScanResult]
}
```
WMScanner implements ScanManaging. Scanner creates Coordinator instance for the respective ScanType and starts the scan. Once the scan is done, returns array of all the scanned barcodes back to the caller (client app)
```swift
protocol ScannerCoordinating {
    var continuationResult: CheckedContinuation<[ScanResult], any Error> { get set }
    func startScan(_ rootVC: UIViewController)
}
```

Each ScanCoordinator implements ScannerCoordinating protocol to iniate scan and use continuationResult to send array of scanResult codes
# Model
```swift
struct ScanResult: Hashable {
   var scannedBarcode: String
   var barcodeType: String = ""
}
```

## AVFoundation Scanner:
AVScannerCoordinator implements ScannerCoordinating and handles routing between viewControllers (Scanning to BarcodeTypes selection, Back to HomeScreen)
AVScannerViewModel is initiated within Coordinator and subscribes to barcodeTypes selection publisher and scannedBarcodes publisher on end of the session (user dismisses scan)

ViewModel provides static data(metaData types) and other configuration. ViewModel publishes data via publisher and coordinator handles routing.

AVScannerController - checks camera permission, configures session and handles metadata output object deetection delegates to present current scanned barcodes. Overlay screen has torch button, selection of barcode types (SwiftUI screen). Controller updates viewModel on scanned codes and routing part

ViewController implements UIAdaptivePresentationControllerDelegate to publish scanned codes on dismiss of the scanner via ViewModel.

## VisionKit DataScanner:
This is available from iOS 16+. VisionKit's scanner has ability to scan text, barcode with quality assurance. Customization is very limited compared to AVFoundation.

VKScanCoordinator implements ScannerCoordinating to initiate scan and send result back to caller.
View is implemented using SwiftUI and presented using UIHostingViewController. Result of scannedCodes is sent back to caller as async checkedContinuation

VisionKitScanCoordinator implements DataScannerViewControllerDelegate to publish scanned codes on each iteration via delegate method
```swift
func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem])
```




