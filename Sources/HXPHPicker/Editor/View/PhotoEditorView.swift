//
//  PhotoEditorView.swift
//  HXPHPicker
//
//  Created by Slience on 2021/4/17.
//

import UIKit

protocol PhotoEditorViewDelegate: AnyObject {
    func editorView(willBeginEditing editorView: PhotoEditorView)
    func editorView(didEndEditing editorView: PhotoEditorView)
    func editorView(willAppearCrop editorView: PhotoEditorView)
    func editorView(didAppear editorView: PhotoEditorView)
    func editorView(willDisappearCrop editorView: PhotoEditorView)
    func editorView(didDisappearCrop editorView: PhotoEditorView)
    
    func editorView(drawViewBeganDraw editorView: PhotoEditorView)
    func editorView(drawViewEndDraw editorView: PhotoEditorView)
}

class PhotoEditorView: UIScrollView, UIGestureRecognizerDelegate {
    weak var editorDelegate: PhotoEditorViewDelegate?
    lazy var imageResizerView: EditorImageResizerView = {
        let imageResizerView = EditorImageResizerView.init(cropConfig: config.cropConfig)
        imageResizerView.imageView.drawView.lineColor = config.brushColors[config.defaultBrushColorIndex].color
        imageResizerView.imageView.drawView.lineWidth = config.brushLineWidth
        imageResizerView.delegate = self
        imageResizerView.imageView.delegate = self
        return imageResizerView
    }()
    
    override var zoomScale: CGFloat {
        didSet {
            imageResizerView.zoomScale = zoomScale
        }
    }
    
    /// 裁剪配置
    var config: PhotoEditorConfiguration
    
    var state: State = .normal
    var imageScale: CGFloat = 1
    var canZoom = true
    var cropSize: CGSize = .zero
    
    var image: UIImage? {
        imageResizerView.imageView.image
    }
    
    var drawEnabled: Bool {
        get {
            imageResizerView.drawEnabled
        }
        set {
            imageResizerView.drawEnabled = newValue
        }
    }
    
    var drawColorHex: String = "#ffffff" {
        didSet {
            imageResizerView.imageView.drawView.lineColor = drawColorHex.color
        }
    }
    
    var canUndoDraw: Bool {
        imageResizerView.imageView.drawView.canUndo
    }
    
    var hasFilter: Bool {
        imageResizerView.filter != nil
    }
    
    init(config: PhotoEditorConfiguration) {
        self.config = config
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1.0
        maximumZoomScale = 10.0
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        clipsToBounds = false
        scrollsToTop = false
        if #available(iOS 11.0, *) {
            contentInsetAdjustmentBehavior = .never
        }
        addSubview(imageResizerView)
    }
    
    func updateImageViewFrame() {
        let imageWidth = width
        var imageHeight: CGFloat
        if cropSize.equalTo(.zero) {
            imageHeight = imageWidth / imageScale
        }else {
            imageHeight = cropSize.height
        }
        let imageX: CGFloat = 0
        var imageY: CGFloat = 0
        if imageHeight < height {
            imageY = (height - imageHeight) * 0.5
            imageResizerView.setViewFrame(CGRect(x: 0, y: -imageY, width: width, height: height))
        }else {
            imageResizerView.setViewFrame(bounds)
        }
        contentSize = CGSize(width: imageWidth, height: imageHeight)
        imageResizerView.frame = CGRect(x: imageX, y: imageY, width: imageWidth, height: imageHeight)
    }
    
    func setImage(_ image: UIImage) {
        imageScale = image.width / image.height
        updateImageViewFrame()
        imageResizerView.setImage(image)
    }
    func updateImage(_ image: UIImage) {
        imageResizerView.updateImage(image)
    }
    func getEditedData() -> PhotoEditData {
        imageResizerView.getEditedData()
    }
    func setEditedData(editedData: PhotoEditData) {
        imageResizerView.filter = editedData.filter
        if editedData.isPortrait != UIDevice.isPortrait {
            return
        }
        if let cropData = editedData.cropData {
            cropSize = cropData.cropSize
            imageResizerView.setCropData(cropData: cropData)
            cancelCropping(canShowMask: false, false)
        }
        imageResizerView.setBrushData(brushData: editedData.brushData)
        updateImageViewFrame()
        if config.cropConfig.isRoundCrop {
            imageResizerView.layer.cornerRadius = cropSize.width * 0.5
        }
    }
    
    func resetZoomScale(_ animated: Bool) {
        if state == .normal {
            canZoom = true
        }
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveLinear]) {
                if self.zoomScale != 1 {
                    self.zoomScale = 1
                }
            } completion: { (isFinished) in
                if self.state == .cropping {
                    self.canZoom = false
                }
            }
        }else {
            if zoomScale != 1 {
                zoomScale = 1
            }
            if state == .cropping {
                canZoom = false
            }
        }
        setContentOffset(CGPoint(x: -contentInset.left, y: -contentInset.top), animated: false)
    }
    
    func startCropping(_ animated: Bool) {
        editorDelegate?.editorView(willAppearCrop: self)
        state = .cropping
        isScrollEnabled = false
        resetZoomScale(animated)
        imageResizerView.startCorpping(animated) { [weak self] () in
            if let self = self {
                self.imageResizerView.zoomScale = self.zoomScale
                self.editorDelegate?.editorView(didAppear: self)
            }
        }
    }
    
    func cancelCropping(canShowMask: Bool = true, _ animated: Bool) {
        editorDelegate?.editorView(willDisappearCrop: self)
        state = .normal
        isScrollEnabled = true
        resetZoomScale(animated)
        imageResizerView.cancelCropping(canShowMask: canShowMask, animated) { [weak self] () in
            if let self = self {
                self.imageResizerView.zoomScale = self.zoomScale
                self.editorDelegate?.editorView(didDisappearCrop: self)
            }
        }
    }
    func canReset() -> Bool {
        return imageResizerView.canReset()
    }
    
    func reset(_ animated: Bool) {
        imageResizerView.reset(animated)
    }
    
    func finishCropping(_ animated: Bool, completion: (() -> Void)? = nil) {
        editorDelegate?.editorView(willDisappearCrop: self)
        state = .normal
        isScrollEnabled = true
        resetZoomScale(animated)
        imageResizerView.finishCropping(animated) { [weak self] () in
            if let self = self {
                self.imageResizerView.zoomScale = self.zoomScale
                self.editorDelegate?.editorView(didDisappearCrop: self)
                if self.config.cropConfig.isRoundCrop {
                    self.imageResizerView.layer.cornerRadius = self.cropSize.width * 0.5
                }
            }
            completion?()
        }
        cropSize = imageResizerView.cropSize
        updateImageViewFrame()
    } 
    func cropping(completion: @escaping (PhotoEditResult?) -> Void) {
        let toRect = imageResizerView.getCroppingRect()
        let inputImage = imageResizerView.imageView.image
        let viewWidth = imageResizerView.imageView.width
        let viewHeight = imageResizerView.imageView.height
        DispatchQueue.global().async {
            if let imageOptions = self.imageResizerView.cropping(inputImage, toRect: toRect, viewWidth: viewWidth, viewHeight: viewHeight) {
                DispatchQueue.main.async {
                    let editResult = PhotoEditResult.init(editedImage: imageOptions.0, editedImageURL: imageOptions.1, imageType: imageOptions.2, editedData: self.getEditedData())
                    completion(editResult)
                }
            }else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    func changedAspectRatio(of aspectRatio: CGSize) {
        imageResizerView.changedAspectRatio(of: aspectRatio)
    }
    func rotate() {
        imageResizerView.rotate()
    }
    func mirrorHorizontally(animated: Bool) {
        imageResizerView.mirrorHorizontally(animated: animated)
    }
    
    func orientationDidChange() {
        cropSize = .zero
        updateImageViewFrame()
        imageResizerView.updateBaseConfig()
    }
    
    func undoAllDraw() {
        imageResizerView.imageView.drawView.emptyCanvas()
    }
    
    func undoDraw() {
        imageResizerView.imageView.drawView.undo()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if state != .cropping && imageResizerView == view {
            if imageResizerView.drawEnabled {
                return imageResizerView.imageView.drawView
            }
            return self
        }else if state == .cropping && self == view {
            return imageResizerView
        }
        return view
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if state == .cropping {
            return false
        }else if imageResizerView.drawEnabled && !gestureRecognizer.isKind(of: UIPinchGestureRecognizer.self) {
            return false
        }
        return true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
extension PhotoEditorView: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if !canZoom {
            return nil
        }
        return imageResizerView
    }
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if !canZoom {
            return
        }
        let offsetX = (scrollView.width > scrollView.contentSize.width) ? (scrollView.width - scrollView.contentSize.width) * 0.5 : 0
        let offsetY = (scrollView.height > scrollView.contentSize.height) ? (scrollView.height - scrollView.contentSize.height) * 0.5 : 0
        let centerX = scrollView.contentSize.width * 0.5 + offsetX
        let centerY = scrollView.contentSize.height * 0.5 + offsetY
        imageResizerView.center = CGPoint(x: centerX, y: centerY);
    }
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        imageResizerView.zoomScale = scale
    }
}
extension PhotoEditorView: PhotoEditorContentViewDelegate {
    func contentView(drawViewBeganDraw contentView: PhotoEditorContentView) {
        editorDelegate?.editorView(drawViewBeganDraw: self)
    }
    func contentView(drawViewEndDraw contentView: PhotoEditorContentView) {
        editorDelegate?.editorView(drawViewEndDraw: self)
    }
}
extension PhotoEditorView: EditorImageResizerViewDelegate {
    func imageResizerView(willChangedMaskRect imageResizerView: EditorImageResizerView) {
        editorDelegate?.editorView(willBeginEditing: self)
    }
    
    func imageResizerView(didEndChangedMaskRect imageResizerView: EditorImageResizerView) {
        editorDelegate?.editorView(didEndEditing: self)
    }
    
    func imageResizerView(willBeginDragging imageResizerView: EditorImageResizerView) {
        editorDelegate?.editorView(willBeginEditing: self)
    }
    
    func imageResizerView(didEndDecelerating imageResizerView: EditorImageResizerView) {
        editorDelegate?.editorView(didEndEditing: self)
    }
    
    func imageResizerView(WillBeginZooming imageResizerView: EditorImageResizerView) {
        editorDelegate?.editorView(willBeginEditing: self)
    }
    
    func imageResizerView(didEndZooming imageResizerView: EditorImageResizerView) {
        editorDelegate?.editorView(didEndEditing: self)
    }
}
