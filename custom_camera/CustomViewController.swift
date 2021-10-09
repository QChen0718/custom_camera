//
//  CustomViewController.swift
//  custom_camera
//
//  Created by white on 2021/10/9.
//

import UIKit
import AVFoundation

class CustomViewController: UIViewController {
    private var captureSession = AVCaptureSession()
    private var sessionQueue: DispatchQueue!
    private var captureDevice: AVCaptureDevice!
    private  var photoOutPut: AVCapturePhotoOutput!
    private var cameraPreviewLayer: AVCaptureVideoPreviewLayer!
    var image: UIImage?
    var usingFrontCamera = false
    lazy var rotatingCameraBtn:UIButton = {
        let btn = UIButton(type: .custom)
        btn.frame = CGRect(x: UIScreen.main.bounds.width-100, y: 64, width: 44, height: 44)
        btn.setTitle("转换", for: .normal)
        btn.backgroundColor = .gray
        btn.addTarget(self, action: #selector(btnClick), for: .touchUpInside)
        return btn
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupDevice()
        setupInput()
        setupPreviewLayer()
        startRunningCaptureSession()
        self.view.addSubview(rotatingCameraBtn)
        // Do any additional setup after loading the view.
    }
    func setupCaptureSession(){
        captureSession.sessionPreset = .photo
        sessionQueue = DispatchQueue(label: "session queue")
    }
    func setupDevice(usingFrontCamera: Bool = false){
        sessionQueue.async {
            let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            let devices = deviceDiscoverySession.devices
            for device in devices {
                if usingFrontCamera && device.position == .front {
                    self.captureDevice = device
                } else if device.position == .back {
                    self.captureDevice = device
                }
            }
        }
    }
    func setupInput() {
        sessionQueue.async {
            do {
                let captureDeviceInput = try AVCaptureDeviceInput(device: self.captureDevice)
                if self.captureSession.canAddInput(captureDeviceInput) {
                    self.captureSession.addInput(captureDeviceInput)
                }
                self.photoOutPut = AVCapturePhotoOutput()
                self.photoOutPut.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format:[AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
                if self.captureSession.canAddOutput(self.photoOutPut) {
                    self.captureSession.addOutput(self.photoOutPut)
                }
            } catch {
                print(error)
            }
        }
    }
    func setupPreviewLayer() {
        cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        cameraPreviewLayer.videoGravity = .resizeAspectFill
        cameraPreviewLayer.connection?.videoOrientation = .portrait
        cameraPreviewLayer.frame = UIScreen.main.bounds
        self.view.layer.insertSublayer(cameraPreviewLayer, at: 0)
    }
    func startRunningCaptureSession() {
        captureSession.startRunning()
    }
    @objc func btnClick(){
        captureSession.beginConfiguration()
        if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                captureSession.removeInput(input)
            }
        }
        usingFrontCamera = !usingFrontCamera
        setupCaptureSession()
        setupDevice(usingFrontCamera: usingFrontCamera)
        setupInput()
        captureSession.commitConfiguration()
        startRunningCaptureSession()
    }
}
