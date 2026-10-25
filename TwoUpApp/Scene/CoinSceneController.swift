import SceneKit
import SwiftUI
import UIKit
import TwoUpCore

/// A first-person view of the ring. The camera is the Spinner's eyes: the kip below, the coins
/// thrown up in front, the crowd standing in a circle beyond. When someone else spins, the camera
/// moves to the edge of the ring instead.
///
/// The engine decides the result; this class only plays it back, so what you see always matches
/// what was settled.
@MainActor
final class CoinSceneController: ObservableObject, TossAnimating {
    let scene = SCNScene()
    let cameraNode = SCNNode()

    private let coins = [SCNNode(), SCNNode()]
    private let crowd = SCNNode()
    private let kip = SCNNode()
    private var crowdFigures: [SCNNode] = []

    // Spinner POV: kip at hand height in front of the camera, coins land on the ground ahead.
    private let spinnerEye = SCNVector3(0, 1.6, 0.9)
    private let spinnerPitch: Float = -10 * .pi / 180
    private let watcherEye = SCNVector3(0, 1.6, 3.6)
    private let watcherPitch: Float = -13 * .pi / 180
    private let kipPosition = SCNVector3(0, 1.1, -0.7)
    private let ringRadius: Float = 3.4

    init() {
        buildEnvironment()
        buildGround()
        buildFence()
        buildLights()
        buildCrowd()
        buildKip()
        buildCoins()
        buildCamera()
        setViewpoint(spinnerIsLocal: true, animated: false)
    }

    // MARK: TossAnimating

    func setViewpoint(spinnerIsLocal: Bool, animated: Bool) {
        let eye = spinnerIsLocal ? spinnerEye : watcherEye
        let pitch = spinnerIsLocal ? spinnerPitch : watcherPitch
        kip.isHidden = !spinnerIsLocal
        coins.forEach { $0.isHidden = false }
        restCoins(onKip: spinnerIsLocal)
        cameraNode.removeAllActions()
        if animated && !UIAccessibility.isReduceMotionEnabled {
            let move = SCNAction.group([.move(to: eye, duration: 0.8),
                                        .rotateTo(x: CGFloat(pitch), y: 0, z: 0, duration: 0.8, usesShortestUnitArc: true)])
            move.timingMode = .easeInEaseOut
            cameraNode.runAction(move)
        } else {
            cameraNode.position = eye
            cameraNode.eulerAngles = SCNVector3(pitch, 0, 0)
        }
    }

    func animate(_ toss: Toss, spinnerIsLocal: Bool, duration: TimeInterval, reduceMotion: Bool, onLand: @escaping () -> Void) {
        let faces = [toss.first, toss.second]
        let spread: Float = 0.22

        for (i, coin) in coins.enumerated() {
            coin.removeAllActions()
            coin.isHidden = false
            let side: Float = i == 0 ? -1 : 1
            let origin: SCNVector3 = spinnerIsLocal
                ? SCNVector3(kipPosition.x + side * 0.05, kipPosition.y + 0.04, kipPosition.z)
                : SCNVector3(side * 0.05, 1.05, 0)
            let landing: SCNVector3 = spinnerIsLocal
                ? SCNVector3(side * spread, 0.02, -1.7 - Float(i) * 0.12)
                : SCNVector3(side * spread, 0.02, -0.1 * Float(i))
            let peak: SCNVector3 = spinnerIsLocal
                ? SCNVector3(side * 0.18, 2.0, -1.3)
                : SCNVector3(side * 0.12, 2.5, 0)

            let yaw = Float.random(in: 0..<(2 * .pi))
            let tails = faces[i] == .tails

            if reduceMotion {
                coin.position = landing
                coin.simdOrientation = Self.orientation(yaw: yaw, flip: tails ? .pi : 0)
                coin.opacity = 0
                coin.runAction(.sequence([.fadeIn(duration: 0.3), .run { _ in DispatchQueue.main.async(execute: onLand) }]))
                continue
            }

            let turns = Float(5 + i)
            let totalFlip = turns * 2 * .pi + (tails ? .pi : 0)
            let control = SCNVector3(Self.controlPoint(peak.x, origin.x, landing.x),
                                     Self.controlPoint(peak.y, origin.y, landing.y),
                                     Self.controlPoint(peak.z, origin.z, landing.z))
            coin.opacity = 1
            let flight = SCNAction.customAction(duration: duration) { node, elapsed in
                let t = Float(elapsed / CGFloat(duration))
                node.position = SCNVector3(Self.bezier(t, origin.x, control.x, landing.x),
                                           Self.bezier(t, origin.y, control.y, landing.y),
                                           Self.bezier(t, origin.z, control.z, landing.z))
                node.simdOrientation = Self.orientation(yaw: yaw, flip: totalFlip * t)
            }
            let settle = SCNAction.sequence([
                .moveBy(x: 0, y: 0.05, z: 0, duration: 0.07),
                .moveBy(x: 0, y: -0.05, z: 0, duration: 0.09)
            ])
            coin.runAction(.sequence([flight, settle]))
        }

        if !reduceMotion {
            // Look down at the landing spot as the coins fall, then ease back.
            let down = spinnerIsLocal ? spinnerPitch - 0.3 : watcherPitch - 0.1
            let up = spinnerIsLocal ? spinnerPitch : watcherPitch
            cameraNode.runAction(.sequence([
                .wait(duration: duration * 0.45),
                .rotateTo(x: CGFloat(down), y: 0, z: 0, duration: duration * 0.4, usesShortestUnitArc: true),
                .wait(duration: duration * 0.9),
                .rotateTo(x: CGFloat(up), y: 0, z: 0, duration: 0.7, usesShortestUnitArc: true)
            ]), forKey: "toss-look")
            scene.rootNode.runAction(.sequence([
                .wait(duration: duration),
                .run { _ in DispatchQueue.main.async(execute: onLand) }
            ]), forKey: "land")
        }
    }

    func celebrate(positive: Bool, reduceMotion: Bool) {
        guard !reduceMotion else { return }
        for figure in crowdFigures.shuffled().prefix(positive ? 10 : 5) {
            let hop: CGFloat = positive ? 0.18 : 0.06
            figure.runAction(.sequence([
                .wait(duration: .random(in: 0...0.35)),
                .moveBy(x: 0, y: hop, z: 0, duration: 0.14),
                .moveBy(x: 0, y: -hop, z: 0, duration: 0.18)
            ]))
        }
    }

    // MARK: Build

    /// Quadratic Bézier control value so the curve's midpoint is exactly `peak`.
    nonisolated private static func controlPoint(_ peak: Float, _ start: Float, _ end: Float) -> Float {
        let mid: Float = (start + end) / 2
        return 2 * peak - mid
    }

    nonisolated private static func bezier(_ t: Float, _ a: Float, _ c: Float, _ b: Float) -> Float {
        let u: Float = 1 - t
        let first: Float = u * u * a
        let second: Float = 2 * u * t * c
        let third: Float = t * t * b
        return first + second + third
    }

    nonisolated private static func orientation(yaw: Float, flip: Float) -> simd_quatf {
        simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0)) * simd_quatf(angle: flip, axis: SIMD3(1, 0, 0))
    }

    private func buildEnvironment() {
        let panorama = SceneAssets.panorama()
        scene.background.contents = panorama
        scene.lightingEnvironment.contents = panorama
        scene.lightingEnvironment.intensity = 1.1
        scene.fogColor = UIColor(hex: 0x2B1D16)
        scene.fogStartDistance = 14
        scene.fogEndDistance = 40
    }

    private func buildGround() {
        let disc = SCNCylinder(radius: 9, height: 0.02)
        let material = SCNMaterial()
        material.diffuse.contents = SceneAssets.ground()
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(6, 6, 1)
        material.roughness.contents = 0.95
        material.lightingModel = .physicallyBased
        disc.materials = [material]
        let node = SCNNode(geometry: disc)
        node.position.y = -0.01
        scene.rootNode.addChildNode(node)
    }

    /// Timber fence and festoon lights: the pub beer garden, in stand-in form.
    private func buildFence() {
        let radius: Float = 9
        let posts = 48
        let timber = SCNMaterial()
        timber.diffuse.contents = UIColor(hex: 0x4A3324)
        timber.lightingModel = .physicallyBased
        timber.roughness.contents = 0.85
        let bulb = SCNMaterial()
        bulb.diffuse.contents = UIColor(hex: 0xFFE3A6)
        bulb.emission.contents = UIColor(hex: 0xFFC965)    // steady glow, never flashing

        for i in 0..<posts {
            let angle = Float(i) / Float(posts) * 2 * .pi
            let post = SCNNode(geometry: SCNBox(width: 0.14, height: 2.2, length: 0.14, chamferRadius: 0.01))
            post.geometry?.materials = [timber]
            post.position = SCNVector3(sin(angle) * radius, 1.1, cos(angle) * radius)
            scene.rootNode.addChildNode(post)

            let light = SCNNode(geometry: SCNSphere(radius: 0.07))
            light.geometry?.materials = [bulb]
            light.position = SCNVector3(sin(angle) * (radius - 0.1), 2.35 - 0.12 * abs(sin(angle * 4)), cos(angle) * (radius - 0.1))
            scene.rootNode.addChildNode(light)
        }
    }

    private func buildLights() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 250
        ambient.light?.color = UIColor(hex: 0x6B5A8A)
        scene.rootNode.addChildNode(ambient)

        let warm = SCNNode()
        warm.light = SCNLight()
        warm.light?.type = .directional
        warm.light?.intensity = 900
        warm.light?.color = UIColor(hex: 0xFFC27A)
        warm.light?.castsShadow = true
        warm.light?.shadowMode = .deferred
        warm.light?.shadowColor = UIColor.black.withAlphaComponent(0.5)
        warm.eulerAngles = SCNVector3(-0.9, 0.5, 0)
        scene.rootNode.addChildNode(warm)
    }

    private func buildCrowd() {
        scene.rootNode.addChildNode(crowd)
        let photos = SceneAssets.crowdImages()
        let count = 26
        let clothes: [UInt32] = [0x7A4B2A, 0x2F6148, 0x57457A, 0xA83F28, 0x2D5A6B, 0xC8A878, 0x3A3A3F, 0x8A6B4A]
        let skin: [UInt32] = [0xF1C9A5, 0xD9A073, 0xB87A4B, 0x8A5632, 0x5C3A21]

        for i in 0..<count {
            let angle = Float(i) / Float(count) * 2 * .pi + Float.random(in: -0.05...0.05)
            let radius = ringRadius + Float.random(in: 0...0.5)
            let figure = SCNNode()
            figure.position = SCNVector3(sin(angle) * radius, 0, cos(angle) * radius)

            if !photos.isEmpty {
                // Photographic cut-out billboard.
                let image = photos[i % photos.count]
                let height: CGFloat = .random(in: 1.65...1.9)
                let plane = SCNPlane(width: height * image.size.width / image.size.height, height: height)
                plane.firstMaterial?.diffuse.contents = image
                plane.firstMaterial?.isDoubleSided = true
                plane.firstMaterial?.lightingModel = .constant
                let board = SCNNode(geometry: plane)
                board.position.y = Float(height / 2)
                let billboard = SCNBillboardConstraint()
                billboard.freeAxes = .Y
                board.constraints = [billboard]
                figure.addChildNode(board)
            } else {
                // Stand-in silhouette: body, head and sometimes a hat.
                let body = SCNNode(geometry: SCNCapsule(capRadius: 0.22, height: 1.5))
                body.geometry?.firstMaterial = Self.matte(clothes.randomElement()!)
                body.position.y = 0.75
                let head = SCNNode(geometry: SCNSphere(radius: 0.13))
                head.geometry?.firstMaterial = Self.matte(skin.randomElement()!)
                head.position.y = 1.62
                figure.addChildNode(body)
                figure.addChildNode(head)
                if i % 3 == 0 {
                    let hat = SCNNode(geometry: SCNCylinder(radius: 0.2, height: 0.025))
                    hat.geometry?.firstMaterial = Self.matte(0x5A4630)
                    hat.position.y = 1.72
                    let crown = SCNNode(geometry: SCNCylinder(radius: 0.11, height: 0.1))
                    crown.geometry?.firstMaterial = Self.matte(0x5A4630)
                    crown.position.y = 1.77
                    figure.addChildNode(hat)
                    figure.addChildNode(crown)
                }
                figure.eulerAngles.y = angle + .pi    // face the middle of the ring
            }

            crowd.addChildNode(figure)
            crowdFigures.append(figure)

            if !UIAccessibility.isReduceMotionEnabled {
                let sway = SCNAction.sequence([
                    .moveBy(x: 0, y: 0.012, z: 0, duration: .random(in: 1.2...2.0)),
                    .moveBy(x: 0, y: -0.012, z: 0, duration: .random(in: 1.2...2.0))
                ])
                figure.runAction(.repeatForever(sway))
            }
        }
    }

    private static func matte(_ hex: UInt32) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(hex: hex)
        m.lightingModel = .physicallyBased
        m.roughness.contents = 0.9
        return m
    }

    private func buildKip() {
        let board = SCNBox(width: 0.5, height: 0.015, length: 0.09, chamferRadius: 0.004)
        board.firstMaterial = Self.matte(0x6B4A2B)
        let handle = SCNBox(width: 0.14, height: 0.02, length: 0.04, chamferRadius: 0.004)
        handle.firstMaterial = Self.matte(0x6B4A2B)
        kip.addChildNode(SCNNode(geometry: board))
        let h = SCNNode(geometry: handle)
        h.position = SCNVector3(0.3, 0, 0.02)
        kip.addChildNode(h)
        kip.position = kipPosition
        scene.rootNode.addChildNode(kip)
    }

    private func buildCoins() {
        let heads = SceneAssets.coinFace(heads: true)
        let tails = SceneAssets.coinFace(heads: false)
        for coin in coins {
            let cylinder = SCNCylinder(radius: 0.13, height: 0.018)
            func face(_ image: UIImage) -> SCNMaterial {
                let m = SCNMaterial()
                m.lightingModel = .physicallyBased
                m.diffuse.contents = image
                m.metalness.contents = 0.85
                m.roughness.contents = 0.32
                return m
            }
            let side = SCNMaterial()
            side.lightingModel = .physicallyBased
            side.diffuse.contents = UIColor(hex: 0xB9822F)
            side.metalness.contents = 0.9
            side.roughness.contents = 0.4
            // SCNCylinder material order: side, top cap (+Y), bottom cap (-Y). Heads is up at rest.
            cylinder.materials = [side, face(heads), face(tails)]
            coin.geometry = cylinder
            coin.castsShadow = true
            scene.rootNode.addChildNode(coin)
        }
    }

    private func buildCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 68
        camera.zNear = 0.05
        camera.wantsHDR = true
        camera.bloomIntensity = 0.2
        camera.vignettingIntensity = 0.5
        camera.vignettingPower = 1.2
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
    }

    private func restCoins(onKip: Bool) {
        for (i, coin) in coins.enumerated() {
            let side: Float = i == 0 ? -1 : 1
            coin.removeAllActions()
            coin.opacity = 1
            coin.simdOrientation = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
            coin.position = onKip
                ? SCNVector3(kipPosition.x + side * 0.1, kipPosition.y + 0.02, kipPosition.z)
                : SCNVector3(side * 0.2, 0.01, 0)
            coin.isHidden = !onKip
        }
    }
}
