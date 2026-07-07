import AVFoundation
import UIKit

/// Sound + haptics, ported from fx.jsx (WebAudio → AVAudioEngine). A warm pentatonic
/// pluck per fill (pitch wanders by color), an arpeggio for magic-fill, a chord on
/// completion, plus an optional ambient pad. Off by default (mirrors the design).
final class FX {
    static let shared = FX()

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var started = false
    private var enabled = false

    private var ambPlayer: AVAudioPlayerNode?

    // warm pentatonic so any sequence sounds pleasant: G A C D E G A
    private let scale: [Double] = [392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0]

    private init() {
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        let amb = AVAudioPlayerNode()
        engine.attach(amb)
        engine.connect(amb, to: engine.mainMixerNode, format: format)
        ambPlayer = amb
    }

    func setEnabled(_ v: Bool) {
        enabled = v
        if v { start() } else { ambienceOff() }
    }
    func isEnabled() -> Bool { enabled }

    private func start() {
        guard !started else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            try engine.start()
            for p in players { p.play() }
            ambPlayer?.play()
            started = true
        } catch { started = false }
    }

    // MARK: synth

    private func buffer(freq: Double, dur: Double, type: String, gain: Double) -> AVAudioPCMBuffer {
        let sr = format.sampleRate
        let n = AVAudioFrameCount(dur * sr)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        buf.frameLength = n
        let ch = buf.floatChannelData![0]
        let attack = 0.012
        for i in 0..<Int(n) {
            let t = Double(i) / sr
            // exponential attack/decay envelope (approximating the WebAudio ramps)
            let env: Double
            if t < attack { env = (t / attack) * gain }
            else { env = gain * exp(-(t - attack) / (dur * 0.35)) }
            let phase = 2 * Double.pi * freq * t
            let w: Double
            if type == "triangle" {
                w = 2 / Double.pi * asin(sin(phase))
            } else {
                w = sin(phase)
            }
            ch[i] = Float(w * env)
        }
        return buf
    }

    private func play(freq: Double, dur: Double, type: String = "sine", gain: Double = 0.16) {
        guard enabled, started else { return }
        let p = players[next % players.count]; next += 1
        p.scheduleBuffer(buffer(freq: freq, dur: dur, type: type, gain: gain), at: nil, options: [], completionHandler: nil)
    }

    // MARK: public sounds

    /// A soft pluck whose pitch wanders by color index.
    func fill(_ ci: Int) {
        let f = scale[(ci * 2) % scale.count]
        play(freq: f, dur: 0.35, type: "sine", gain: 0.13)
        play(freq: f * 2.001, dur: 0.22, type: "triangle", gain: 0.04)
    }

    func magic() {
        guard enabled else { return }
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) { [weak self] in
                guard let self else { return }
                self.play(freq: self.scale[i + 1], dur: 0.3, type: "triangle", gain: 0.08)
            }
        }
    }

    func complete() {
        guard enabled else { return }
        let chord = [523.25, 659.25, 783.99, 1046.5]
        for (i, f) in chord.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.07) { [weak self] in
                self?.play(freq: f, dur: 1.1, type: "sine", gain: 0.12)
            }
        }
    }

    func ambienceOn() {
        guard enabled, started, let amb = ambPlayer else { return }
        // a slow, low looping pad
        let sr = format.sampleRate
        let dur = 4.0
        let n = AVAudioFrameCount(dur * sr)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        buf.frameLength = n
        let ch = buf.floatChannelData![0]
        let freqs = [196.0, 261.63, 392.0]
        for i in 0..<Int(n) {
            let t = Double(i) / sr
            var s = 0.0
            for (k, f) in freqs.enumerated() {
                let trem = 0.75 + 0.25 * sin(2 * Double.pi * (0.07 + Double(k) * 0.03) * t)
                s += sin(2 * Double.pi * f * t) * (0.5 / Double(k + 1)) * trem
            }
            ch[i] = Float(s * 0.08)
        }
        amb.scheduleBuffer(buf, at: nil, options: [.loops], completionHandler: nil)
    }

    func ambienceOff() {
        ambPlayer?.stop()
        if started { ambPlayer?.play() } // keep node running for next time
    }

    // MARK: haptics

    func haptic(_ kind: String = "fill") {
        switch kind {
        case "wrong": UINotificationFeedbackGenerator().notificationOccurred(.error)
        case "complete": UINotificationFeedbackGenerator().notificationOccurred(.success)
        default: UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
        }
    }
}
