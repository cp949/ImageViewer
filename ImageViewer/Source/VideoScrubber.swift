//
//  VideoScrubber.swift
//  ImageViewer
//
//  Created by Kristian Angyal on 08/08/2016.
//  Copyright © 2016 MailOnline. All rights reserved.
//

import UIKit
import AVFoundation

open class VideoScrubber: UIControl {

    let playButton = UIButton.playButton(width: 50, height: 40)
    let pauseButton = UIButton.pauseButton(width: 50, height: 40)
    let replayButton = UIButton.replayButton(width: 50, height: 40)

    let scrubber = Slider.createSlider(320, height: 20, pointerDiameter: 10, barHeight: 2)
    let timeLabel = UILabel(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 50, height: 20)))
    var duration: TimeInterval?
    fileprivate var periodicObserver: AnyObject?
    fileprivate var stoppedSlidingTimeStamp = Date()

    weak var player: AVPlayer? {

        willSet {

            // jjfive bug fix
            // if newValue == nil {

                if let player = player {

                    ///KVO
                    player.removeObserver(self, forKeyPath: "status")
                    player.removeObserver(self, forKeyPath: "rate")

                    ///NC
                    NotificationCenter.default.removeObserver(self)

                    ///TIMER
                    if let periodicObserver = self.periodicObserver {

                        player.removeTimeObserver(periodicObserver)
                        self.periodicObserver = nil
                    }
                }
            //}
        }

        didSet {

            if let player = player {

                ///KVO
                player.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
                player.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil)

                ///NC
                NotificationCenter.default.addObserver(self, selector: #selector(didEndPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)

                ///TIMER
                periodicObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1), queue: nil, using: { [weak self] time in
                    self?.update()
                }) as AnyObject?

                self.update()
            }
        }
    }

    override init(frame: CGRect) {

        super.init(frame: frame)
        setup()
    }

    public required init?(coder aDecoder: NSCoder) {

        super.init(coder: aDecoder)
        setup()
    }

    deinit {

        player?.removeObserver(self, forKeyPath: "status")
        player?.removeObserver(self, forKeyPath: "rate")
        scrubber.removeObserver(self, forKeyPath: "isSliding")

        if let periodicObserver = self.periodicObserver {

            player?.removeTimeObserver(periodicObserver)
            self.periodicObserver = nil
        }
    }

    func didEndPlaying() {

        self.playButton.isHidden = true
        self.pauseButton.isHidden = true
        self.replayButton.isHidden = false
    }

    func setup() {

        self.clipsToBounds = true
        pauseButton.isHidden = true
        replayButton.isHidden = true

        scrubber.minimumValue = 0
        scrubber.maximumValue = 1000
        scrubber.value = 0

        timeLabel.attributedText = NSAttributedString(string: "--:--", attributes: [NSForegroundColorAttributeName : UIColor.white, NSFontAttributeName : UIFont.systemFont(ofSize: 12)])
        timeLabel.textAlignment =  .center

        playButton.addTarget(self, action: #selector(play), for: UIControlEvents.touchUpInside)
        pauseButton.addTarget(self, action: #selector(pause), for: UIControlEvents.touchUpInside)
        replayButton.addTarget(self, action: #selector(replay), for: UIControlEvents.touchUpInside)
        scrubber.addTarget(self, action: #selector(updateCurrentTime), for: UIControlEvents.valueChanged)
        scrubber.addTarget(self, action: #selector(seekToTime), for: [UIControlEvents.touchUpInside, UIControlEvents.touchUpOutside])

        self.addSubviews(playButton, pauseButton, replayButton, scrubber, timeLabel)

        scrubber.addObserver(self, forKeyPath: "isSliding", options: NSKeyValueObservingOptions.new, context: nil)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        playButton.center = self.boundsCenter
        playButton.frame.origin.x = 0
        pauseButton.frame = playButton.frame
        replayButton.frame = playButton.frame

        timeLabel.center = self.boundsCenter
        timeLabel.frame.origin.x = self.bounds.maxX - timeLabel.bounds.width

        scrubber.bounds.size.width = self.bounds.width - playButton.bounds.width - timeLabel.bounds.width
        scrubber.bounds.size.height = 20
        scrubber.center = self.boundsCenter
        scrubber.frame.origin.x = playButton.frame.maxX
    }

    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {

        if keyPath == "isSliding" {

            if scrubber.isSliding == false {

                stoppedSlidingTimeStamp = Date()
            }
        }

        else if keyPath == "rate" || keyPath == "status" {

            self.update()
        }
    }

    func play() {

        self.player?.play()
    }

    func replay() {

        self.player?.seek(to: CMTime(value:0 , timescale: 1))
        self.player?.play()
    }

    func pause() {

        self.player?.pause()
    }

    func seekToTime() {

        let progress = scrubber.value / scrubber.maximumValue //naturally will be between 0 to 1

        if let player = self.player, let currentItem =  player.currentItem {

            let time = currentItem.duration.seconds * Double(progress)
            player.seek(to: CMTime(seconds: time, preferredTimescale: 1))
        }
    }

    func update() {

        updateButtons()
        updateDuration()
        updateScrubber()
        updateCurrentTime()
    }

    func updateButtons() {

        if let player = self.player {

            self.playButton.isHidden = player.isPlaying()
            self.pauseButton.isHidden = !self.playButton.isHidden
            self.replayButton.isHidden = true
        }
    }

    func updateDuration() {

        if let duration = self.player?.currentItem?.duration {

            self.duration = (duration.isNumeric) ? duration.seconds : nil
        }
    }

    func updateScrubber() {

        guard scrubber.isSliding == false else { return }

        let timeElapsed = Date().timeIntervalSince( stoppedSlidingTimeStamp)
        guard timeElapsed > 1 else {
            return
        }

        if let player = self.player, let duration = self.duration {

            let progress = player.currentTime().seconds / duration

            UIView.animate(withDuration: 0.9, animations: { [weak self] in

                if let strongSelf = self {

                    strongSelf.scrubber.value = Float(progress) * strongSelf.scrubber.maximumValue
                }
            })
        }
    }

    func updateCurrentTime() {

        if let duration = self.duration , self.duration != nil {

            let sliderProgress = scrubber.value / scrubber.maximumValue
            let currentTime = Double(sliderProgress) * duration

            let timeString = stringFromTimeInterval(currentTime as TimeInterval)

            timeLabel.attributedText = NSAttributedString(string: timeString, attributes: [NSForegroundColorAttributeName : UIColor.white, NSFontAttributeName : UIFont.systemFont(ofSize: 12)])
        }
        else {
            timeLabel.attributedText = NSAttributedString(string: "--:--", attributes: [NSForegroundColorAttributeName : UIColor.white, NSFontAttributeName : UIFont.systemFont(ofSize: 12)])
        }
    }

    func stringFromTimeInterval(_ interval:TimeInterval) -> String {

        let timeInterval = NSInteger(interval)

        let seconds = timeInterval % 60
        let minutes = (timeInterval / 60) % 60
        //let hours = (timeInterval / 3600)

        return NSString(format: "%0.2d:%0.2d",minutes,seconds) as String
        //return NSString(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds) as String
    }
}
