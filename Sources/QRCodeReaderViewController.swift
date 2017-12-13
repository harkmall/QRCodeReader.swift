/*
 * QRCodeReader.swift
 *
 * Copyright 2014-present Yannick Loriot.
 * http://yannickloriot.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

import UIKit
import AVFoundation

/// Convenient controller to display a view to scan/read 1D or 2D bar codes like the QRCodes. It is based on the `AVFoundation` framework from Apple. It aims to replace ZXing or ZBar for iOS 7 and over.
public class QRCodeReaderViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    /// The code reader object used to scan the bar code.
    public let codeReader: QRCodeReader
    let imagePicker = UIImagePickerController()
    
    let readerView: QRCodeReaderContainer
    let startScanningAtLoad: Bool
    let showCancelButton: Bool
    let showSwitchCameraButton: Bool
    let showTorchButton: Bool
    let showOverlayView: Bool
    let showScanQRFromImageButton: Bool
    
    // MARK: - Managing the Callback Responders
    
    /// The receiver's delegate that will be called when a result is found.
    public weak var delegate: QRCodeReaderViewControllerDelegate?
    
    /// The completion blocak that will be called when a result is found.
    public var completionBlock: ((QRCodeReaderResult?) -> Void)?
    
    deinit {
        codeReader.stopScanning()
        
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Creating the View Controller
    
    /**
     Initializes a view controller using a builder.
     
     - parameter builder: A QRCodeViewController builder object.
     */
    required public init(builder: QRCodeReaderViewControllerBuilder) {
        readerView                = builder.readerView
        startScanningAtLoad       = builder.startScanningAtLoad
        codeReader                = builder.reader
        showCancelButton          = builder.showCancelButton
        showSwitchCameraButton    = builder.showSwitchCameraButton
        showTorchButton           = builder.showTorchButton
        showOverlayView           = builder.showOverlayView
        showScanQRFromImageButton = builder.showScanQRFromImageButton
        
        super.init(nibName: nil, bundle: nil)
        
        view.backgroundColor = .black
        
        codeReader.didFindCode = { [weak self] resultAsObject in
            if let weakSelf = self {
                if let qrv = weakSelf.readerView.displayable as? QRCodeReaderView {
                    qrv.addGreenBorder()
                }
                weakSelf.completionBlock?(resultAsObject)
                weakSelf.delegate?.reader(weakSelf, didScanResult: resultAsObject)
            }
        }
        
        codeReader.didFailDecoding = { [weak self] in
            if let weakSelf = self {
                if let qrv = weakSelf.readerView.displayable as? QRCodeReaderView {
                    qrv.addRedBorder()
                }
            }
        }
        
        setupUIComponentsWithCancelButtonTitle(builder.cancelButtonTitle, scanFromPhotosButtonTitle: builder.scanFromPhotosButtonTitle)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        codeReader                = QRCodeReader()
        readerView                = QRCodeReaderContainer(displayable: QRCodeReaderView())
        startScanningAtLoad       = false
        showCancelButton          = false
        showTorchButton           = false
        showSwitchCameraButton    = false
        showOverlayView           = false
        showScanQRFromImageButton = false
        
        super.init(coder: aDecoder)
    }
    
    // MARK: - Responding to View Events
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if startScanningAtLoad {
            startScanning()
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        stopScanning()
        
        super.viewWillDisappear(animated)
    }
    
    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        codeReader.previewLayer.frame = view.bounds
    }
    
    // MARK: - Initializing the AV Components
    
    private func setupUIComponentsWithCancelButtonTitle(_ cancelButtonTitle: String, scanFromPhotosButtonTitle: String) {
        view.addSubview(readerView.view)
        
        let sscb = showSwitchCameraButton && codeReader.hasFrontDevice
        let stb  = showTorchButton && codeReader.isTorchAvailable
        
        readerView.view.translatesAutoresizingMaskIntoConstraints = false
        readerView.setupComponents(showCancelButton: showCancelButton, showSwitchCameraButton: sscb, showTorchButton: stb, showScanFromPhotosButton: showScanQRFromImageButton,  showOverlayView: showOverlayView, reader: codeReader)
        
        // Setup action methods
        
        readerView.displayable.switchCameraButton?.addTarget(self, action: #selector(switchCameraAction), for: .touchUpInside)
        readerView.displayable.toggleTorchButton?.addTarget(self, action: #selector(toggleTorchAction), for: .touchUpInside)
        readerView.displayable.cancelButton?.setTitle(cancelButtonTitle, for: .normal)
        readerView.displayable.cancelButton?.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        readerView.displayable.scanFromPhotosButton?.setTitle(scanFromPhotosButtonTitle, for: .normal)
        readerView.displayable.scanFromPhotosButton?.addTarget(self, action: #selector(scanFromPhotosAction), for: .touchUpInside)
        
        // Setup constraints
        
        for attribute in [NSLayoutAttribute.left, NSLayoutAttribute.top, NSLayoutAttribute.right, NSLayoutAttribute.bottom] {
            view.addConstraint(NSLayoutConstraint(item: readerView.view, attribute: attribute, relatedBy: .equal, toItem: view, attribute: attribute, multiplier: 1, constant: 0))
        }
    }
    
    // MARK: - Controlling the Reader
    
    /// Starts scanning the codes.
    public func startScanning() {
        codeReader.startScanning()
    }
    
    /// Stops scanning the codes.
    public func stopScanning() {
        codeReader.stopScanning()
    }
    
    // MARK: - Catching Button Events
    
    @objc func cancelAction(_ button: UIButton) {
        codeReader.stopScanning()
        
        if let _completionBlock = completionBlock {
            _completionBlock(nil)
        }
        
        delegate?.readerDidCancel(self)
    }
    
    @objc func switchCameraAction(_ button: SwitchCameraButton) {
        if let newDevice = codeReader.switchDeviceInput() {
            delegate?.reader(self, didSwitchCamera: newDevice)
        }
    }
    
    @objc func toggleTorchAction(_ button: ToggleTorchButton) {
        codeReader.toggleTorch()
    }
    
    @objc func scanFromPhotosAction(_ button: UIButton) {
        stopScanning()
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    //MARK: - UIImagePicker Delegate Methods
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            codeReader.scanQRCode(fromImage: pickedImage)
        }
        dismiss(animated: true, completion: nil)
        startScanning()
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
        startScanning()
    }
    
}
