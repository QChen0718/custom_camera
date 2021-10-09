//
//  ViewController.swift
//  custom_camera
//
//  Created by white on 2021/10/8.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    @IBAction func btnClick(_ sender: Any) {
        beganTakePicture = true
    }
    var device:AVCaptureDevice? //获取设备：摄像头
    var captureSession:AVCaptureSession? //会话，协调者input到output的数据传输，input和output的桥梁
    var previewLayer:AVCaptureVideoPreviewLayer? //图像预览层，实时显示捕获的图像
    var output:AVCaptureVideoDataOutput? //图像流输出
    var beganTakePicture:Bool = false //相机开始拍照
    
    lazy var photoImageView:UIImageView={
        let imageView = UIImageView(frame: self.view.bounds)
        imageView.backgroundColor = UIColor.red
        return imageView
    }()
    
    lazy var photoBtn:UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = CGRect(x: 100, y: UIScreen.main.bounds.height-150, width: 50, height: 50)
        btn.setTitle("拍照", for: .normal)
        btn.backgroundColor = .red
        btn.tag = 100
        btn.addTarget(self, action: #selector(btnClicks), for: .touchUpInside)
        return btn
    }()
    lazy var startBtn:UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = CGRect(x: 200, y: UIScreen.main.bounds.height-150, width: 50, height: 50)
        btn.setTitle("开始", for: .normal)
        btn.backgroundColor = .blue
        btn.tag = 200
        btn.addTarget(self, action: #selector(btnClicks), for: .touchUpInside)
        return btn
    }()
    lazy var rotatingCameraBtn:UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = CGRect(x: UIScreen.main.bounds.width-100, y: 64, width: 44, height: 44)
        btn.setTitle("转换", for: .normal)
        btn.backgroundColor = .gray
        btn.tag = 300
        btn.addTarget(self, action: #selector(btnClicks), for: .touchUpInside)
        return btn
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        cameraDistrict()
        configurationSession()
        self.view.addSubview(photoImageView)
        photoImageView.isHidden = true
        self.view.addSubview(photoBtn)
        self.view.addSubview(startBtn)
        self.view.addSubview(rotatingCameraBtn)
        
    }

    func cameraDistrict() {
        captureSession = AVCaptureSession()
//        sessionPreset 用于设置output输出流的画面质量
        guard let captureSession = captureSession else {
            return
        }
        if UIDevice.current.userInterfaceIdiom == .phone {
            captureSession.sessionPreset = AVCaptureSession.Preset.vga640x480
        } else {
            captureSession.sessionPreset = AVCaptureSession.Preset.photo
        }
//        设置为高分辨率
        if captureSession.canSetSessionPreset(AVCaptureSession.Preset(rawValue: "AVCaptureSessionPreset1280x720")) {
            captureSession.sessionPreset = AVCaptureSession.Preset(rawValue: "AVCaptureSessionPreset1280x720")
        }
        setCamera(position: .back)
    }
    
    func setCamera(position:AVCaptureDevice.Position) {
        // 获取输入设备,builtInWideAngleCamera是通用相机,AVMediaType.video代表视频媒体,back表示前置摄像头,如果需要后置摄像头修改为front
        if #available(iOS 10.0, *) {
            let availbleDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: position).devices
            device = availbleDevices.first
        }else {
            let devices = AVCaptureDevice.devices(for: .video)
            guard devices.count > 0 else {
                return
            }
            guard let device = devices.filter({ return $0.position == position
            }).first else {
                return
            }
            self.device = device
        }
    }
    
    func configurationSession() {
        captureSession?.beginConfiguration()
        guard let captureSession = captureSession else {
            return
        }
        do {
//            将后置摄像头作为session的input 输入流
            guard let device = device else {
                return
            }
          let captureDeviceInput =  try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(captureDeviceInput) {
                captureSession.addInput(captureDeviceInput)
            }
            
        } catch {
            print(error.localizedDescription)
        }
        
//        设定视频预览层，也就是相机预览layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.view.layer.addSublayer(previewLayer ?? CALayer())
        previewLayer?.frame = self.view.bounds
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill ///相机页面展现形式-拉伸充满frame
        
//        设定输出流
        output = AVCaptureVideoDataOutput()
//        指定像素格式
        output?.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString):NSNumber(value: kCVPixelFormatType_32BGRA)] as [String:Any]
        // 是否直接丢弃处理旧帧时捕获的新帧,默认为True,如果改为false会大幅提高内存使用
        output?.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(output!) {
            captureSession.addOutput(output!)
        }
        // beginConfiguration()和commitConfiguration()方法中的修改将在commit时同时提交
        captureSession.commitConfiguration()
        captureSession.startRunning()
        
        let queue = DispatchQueue(label: "com.brianadvent.captureQueue")
        output?.setSampleBufferDelegate(self, queue: queue)
        
        let captureConnection = output?.connection(with: .video)
        if captureConnection?.isVideoStabilizationSupported == true {
            /// 这个很重要 这个是为了拍照完成，防止图片旋转90度
            captureConnection?.videoOrientation = self.getCaptureVideoOrientation()
        }
        
    }
    
    func getCaptureVideoOrientation() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait,.faceUp,.faceDown:
            return .portrait
        case .portraitUpsideDown: // 如果这里设置成AVCaptureVideoOrientationPortraitUpsideDown,则视频方向和拍摄时的方向是相反的。
            return .portrait
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
    
    /// CMSampleBufferRef=>UIImage
    func imageConvert(sampleBuffer:CMSampleBuffer?) -> UIImage? {
        guard sampleBuffer != nil && CMSampleBufferIsValid(sampleBuffer!) == true else {
            return nil
        }
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer!)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer!)
        return UIImage(ciImage: ciImage)
    }
}

extension ViewController:AVCaptureVideoDataOutputSampleBufferDelegate{
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if beganTakePicture == true {
            beganTakePicture = false
            ///注意在主线程中执行
            DispatchQueue.main.async {
//                #if false
                self.photoImageView.image = self.imageConvert(sampleBuffer: sampleBuffer)
                self.captureSession?.stopRunning()
                self.photoImageView.isHidden = false
//                #endif
            }
        }
    }
    
    @objc func btnClicks(btn:UIButton){
        if btn.tag == 100 {
            beganTakePicture = true
        }else if btn.tag == 200{
            self.photoImageView.isHidden = true
            self.captureSession?.startRunning()
        }else {
//            btn.isSelected = !btn.isSelected
//            setCamera(position: .front)
            captureSession?.stopRunning()
            self.present(VideoViewController(), animated: true, completion: nil)
        }
    }
}
