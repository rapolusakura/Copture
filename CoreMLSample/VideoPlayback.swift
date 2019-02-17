//
//  VideoPlayback.swift
//  CoreMLSample
//
//  Created by Sakura Rapolu on 2/17/19.
//  Copyright © 2019 杨萧玉. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class VideoPlayback: UIViewController {
    
    let avPlayer = AVPlayer()
    var avPlayerLayer: AVPlayerLayer!
    
    var videoURL: URL!
    //connect this to your uiview in storyboard
    @IBOutlet var videoView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        avPlayerLayer = AVPlayerLayer(player: avPlayer)
        avPlayerLayer.frame = view.bounds
        avPlayerLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoView.layer.insertSublayer(avPlayerLayer, at: 0)
        
        view.layoutIfNeeded()
        
        let playerItem = AVPlayerItem(url: videoURL as URL)
        avPlayer.replaceCurrentItem(with: playerItem)
        
        avPlayer.play()
    }
}
