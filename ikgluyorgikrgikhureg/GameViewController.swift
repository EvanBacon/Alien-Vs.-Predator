//
//  GameViewController.swift
//  Alien Vs. Predator 
//
//  Created by Evan Bacon on 7/2/16.
//  Copyright (c) 2016 brix. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit

class GameViewController: UIViewController, UIGestureRecognizerDelegate, SCNSceneRendererDelegate  {
    
    var hero: SCNNode!
    var camNode: SCNNode!
    var gunNode: SCNNode!
    
    //Controls
    var lookGesture: UIPanGestureRecognizer!
    var walkGesture: UIPanGestureRecognizer!
    var elevation: Float = 0
    
    let LookSensetivity = Float(200) //200
    let WalkSensetivity = Float(10) //50
    
    //Gun Animations
    var animBobbing: SCNAction!
    var animRunning: SCNAction!
    var animSwap: SCNAction!
    var animAim: SCNAction!
    var animReturnToStart: SCNAction!
    var gunStartingPosition: SCNVector3!
    var gunStartingRotation: SCNVector3!
    
    //Shooting gesture
    var fireGesture: FireGestureRecognizer!
    var tapCount = 0
    var lastTappedFire: TimeInterval = 0
    var lastFired: TimeInterval = 0
    var bullets = [SCNNode]()
    
    var enemys = [SCNNode]()
    
    let autofireTapTimeThreshold = 0.2
    let maxRoundsPerSecond = 30
    let bulletRadius = 0.05
    let bulletImpulse = 15
    let maxBullets = 100
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/level.scn")!
        
        scene.physicsWorld.gravity = SCNVector3(x: 0, y: -9, z: 0)
        scene.physicsWorld.timeStep = 1.0/360
        
        scene.rootNode.childNode(withName: "floor", recursively: true)?.opacity = 1.0
        
        setupPlayer(scene)
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        scnView.scene = scene
        // allows the user to manipulate the camera
        //        scnView.allowsCameraControl = true
        scnView.showsStatistics = true
        
        setupGestures()
        
        setupEnemys(scene)
    }
    
    func setupEnemys(_ parent: SCNScene){
        var enemyScene = SCNScene(named: "Alien_Warrior.scn")!
        for _ in 0..<10 {
            self.createEnemyFromScene(enemyScene, parent: parent)
        }
        
        enemyScene = SCNScene(named: "Predator_Youngblood.scn")!
        for _ in 0..<10 {
            self.createEnemyFromScene(enemyScene, parent: parent)
        }
    }
    
    func createEnemyFromScene(_ enemyScene: SCNScene, parent: SCNScene){
        if let enemy = enemyScene.rootNode.childNode(withName: "Main", recursively: false)?.clone() {
            
            print("Enemy Spawned")
            //                enemy.eulerAngles = SCNVector3Make(0, Float(rand()%360), 0)
            //                enemy.eulerAngles = SCNVector3Make( Float(rand()%360), 0,0)
            
            
            enemy.flattenedClone()
            var min = SCNVector3Zero
            var max = SCNVector3Zero
            enemy.__getBoundingBoxMin(&min, max: &max)
            
            let size = SCNVector3Make(Float(max.x - min.x), Float(max.y - min.y), Float(max.z - min.z))
            
            print(min)
            print(max)
            
            let aRand = Float(arc4random() % 300)
            let bRand = Float(arc4random() % 300)
            enemy.position = SCNVector3(
                x: aRand - 150,
                y: 10,
                z: bRand - 150
            )
            
            enemy.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: SCNBox(width: CGFloat(size.x), height: CGFloat(size.y/2), length: CGFloat(size.z), chamferRadius: 0), options: nil))
            enemy.physicsBody?.angularVelocityFactor = SCNVector3Make(1, 0, 1)
            enemy.name = "enemy"
            parent.rootNode.addChildNode(enemy)
            
            enemys.append(enemy)
            
        }

        
    }
    
    func setupAnims(){
        animBobbing = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.1, z: 0.15, duration: 0.5),
                SCNAction.moveBy(x: 0, y: -0.1, z: -0.15, duration: 0.6)
                ]))
        
        animRunning = SCNAction.group([
            SCNAction.rotateTo(x: CGFloat(0), y: CGFloat(63), z: CGFloat(0), duration: 0.3),
            //            SCNAction.moveTo(SCNVector3Make(0.583, 0, -0.332), duration: 0.3),
            
            //            SCNAction.repeatActionForever(
            //            SCNAction.sequence([
            //                SCNAction.moveByX(0, y: 0.1, z: 0, duration: 0.5),
            //                SCNAction.moveByX(0, y: -0.1, z: 0, duration: 0.6)
            //                ])
            //            )
            ])
        
        animSwap = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.2, z: 0.15, duration: 0.5),
                SCNAction.moveBy(x: 0, y: -0.2, z: -0.15, duration: 0.6)
                ]))
        
        animAim = SCNAction.repeatForever(
            SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.2, z: 0.15, duration: 0.5),
                SCNAction.moveBy(x: 0, y: -0.2, z: -0.15, duration: 0.6)
                ]))
        
        animReturnToStart =
            SCNAction.group([
                SCNAction.move(to: SCNVector3Zero, duration: 0.3),
                SCNAction.rotateTo(x: CGFloat(0), y: CGFloat(0), z: CGFloat(0), duration: 0.3)
                ])
        
        //        animReturnToStart =
        //            SCNAction.moveTo(gunStartingPosition, duration: 0.3)
        
        
    }
    
    func setupPlayer(_ parent: SCNScene){
        
        let playerScene = SCNScene(named: "art.scnassets/player.scn")!
        
        hero = playerScene.rootNode.childNode(withName: "Player", recursively: true)!
        
        hero.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: SCNCylinder(radius: 0.2, height: 1), options: nil))
        hero.physicsBody?.angularDamping = 0.9999999
        hero.physicsBody?.damping = 0.9999999
        hero.physicsBody?.rollingFriction = 0
        hero.physicsBody?.friction = 0
        hero.physicsBody?.restitution = 0
        hero.physicsBody?.velocityFactor = SCNVector3(x: 1, y: 0, z: 1) //not affected by gravity
        
        hero.position = SCNVector3Make(0, 5, 0)
        parent.rootNode.addChildNode(hero)
        
        camNode = hero.childNode(withName: "camera", recursively: true)!
        
        gunNode = hero.childNode(withName: "GunNode", recursively: true)!
        
        gunStartingPosition = gunNode.presentation.position
        //        gunStartingRotation = SCNVector3Make(91.104, -4.492, 179.914)
        gunStartingRotation = gunNode.eulerAngles
        print("\(gunNode.eulerAngles)")
        
        gunStartingRotation = SCNVector3Make(0.0,0.0,0.0)
        
        setupAnims()
        gunNode.runAction(animBobbing)
    }
    
    func setupGestures(){
        let scnView = self.view as! SCNView
        
        scnView.delegate = self
        
        // add a tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(GameViewController.handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
        //look gesture
        lookGesture = UIPanGestureRecognizer(target: self, action: #selector(GameViewController.lookGestureRecognized(_:)))
        lookGesture.delegate = self
        view.addGestureRecognizer(lookGesture)
        
        //walk gesture
        walkGesture = UIPanGestureRecognizer(target: self, action: #selector(GameViewController.walkGestureRecognized(_:)))
        walkGesture.delegate = self
        view.addGestureRecognizer(walkGesture)
        
        //fire gesture
        fireGesture = FireGestureRecognizer(target: self, action: #selector(GameViewController.fireGestureRecognized(_:)))
        fireGesture.delegate = self
        view.addGestureRecognizer(fireGesture)
    }
    
    func fireGestureRecognized(_ gesture: FireGestureRecognizer) {
        
        //update timestamp
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastTappedFire < autofireTapTimeThreshold {
            tapCount += 1
            
            let flare = gunNode.childNode(withName: "Flare", recursively: true)!
            if (flare.isHidden) {
                flare.isHidden = false
            }
        } else {
            tapCount = 1
            
            let flare = gunNode.childNode(withName: "Flare", recursively: true)!
            if (flare.isHidden == false) {
                flare.isHidden = true
            }
            
        }
        lastTappedFire = now
        
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        if gestureRecognizer == lookGesture {
            return touch.location(in: view).x > view.frame.size.width / 2
        } else if gestureRecognizer == walkGesture {
            return touch.location(in: view).x < view.frame.size.width / 2
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        return true
    }
    
    func lookGestureRecognized(_ gesture: UIPanGestureRecognizer) {
        
        gunNode.constraints = []
        
        
        //get translation and convert to rotation
        let translation = gesture.translation(in: self.view)
        let hAngle = acos(Float(translation.x) / LookSensetivity) - Float(M_PI_2)
        let vAngle = acos(Float(translation.y) / LookSensetivity) - Float(M_PI_2)
        
        //rotate hero
        hero.physicsBody?.applyTorque(SCNVector4(x: 0, y: 1, z: 0, w: hAngle), asImpulse: true)
        
        //tilt camera
        elevation = max(Float(-M_PI_4), min(Float(M_PI_4), elevation + vAngle))
        camNode.rotation = SCNVector4(x: 1, y: 0, z: 0, w: elevation)
        gunNode.rotation = SCNVector4(x: 1, y: 0, z: 0, w: elevation)
        
        //reset translation
        gesture.setTranslation(CGPoint.zero, in: self.view)
    }
    
    func walkGestureRecognized(_ gesture: UIPanGestureRecognizer) {
        
        if gesture.state == UIGestureRecognizerState.ended || gesture.state == UIGestureRecognizerState.cancelled {
            gesture.setTranslation(CGPoint.zero, in: self.view)
            
            //            startAnimation(animBobbing)
        }
        else if gesture.state == UIGestureRecognizerState.began {
            //            startAnimation(animRunning)
            
        }
    }
    
    func startAnimation(_ newAnim: SCNAction){
        gunNode.removeAllActions()
        gunNode.runAction(animReturnToStart, completionHandler:{
            //            self.gunNode.eulerAngles = self.gunStartingRotation
            self.gunNode.runAction(newAnim)
        })
    }
    
    
    func renderer(_ aRenderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        handleWalking()
        handleShooting()
    }
    
    func handleShooting(){
        //handle firing
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastTappedFire < autofireTapTimeThreshold {
            let fireRate = min(Double(maxRoundsPerSecond), Double(tapCount) / autofireTapTimeThreshold)
            if now - lastFired > 1 / fireRate {
                
                //                let scnView = self.view as! SCNView
                //                scnView.scene.
                //                if ()
                
                
                
                //                //get hero direction vector
                //                let angle = hero.presentationNode().rotation.w * heroNode.presentationNode().rotation.y
                //                var direction = SCNVector3(x: -sin(angle), y: 0, z: -cos(angle))
                //
                //                //get elevation
                //                direction = SCNVector3(x: cos(elevation) * direction.x, y: sin(elevation), z: cos(elevation) * direction.z)
                //
                //                //create or recycle bullet node
                //                let bulletNode: SCNNode = {
                //                    if self.bullets.count < self.maxBullets {
                //                        return SCNNode()
                //                    } else {
                //                        return self.bullets.removeAtIndex(0)
                //                    }
                //                    }()
                //                bullets.append(bulletNode)
                //                bulletNode.geometry = SCNBox(width: CGFloat(bulletRadius) * 2, height: CGFloat(bulletRadius) * 2, length: CGFloat(bulletRadius) * 2, chamferRadius: CGFloat(bulletRadius))
                //                bulletNode.position = SCNVector3(x: hero.presentationNode().position.x, y: 0.4, z: hero.presentationNode().position.z)
                //                bulletNode.physicsBody = SCNPhysicsBody(type: .Dynamic, shape: SCNPhysicsShape(geometry: bulletNode.geometry!, options: nil))
                ////                bulletNode.physicsBody?.categoryBitMask = CollisionCategory.Bullet
                ////                bulletNode.physicsBody?.collisionBitMask = CollisionCategory.All ^ CollisionCategory.Hero
                //                bulletNode.physicsBody?.velocityFactor = SCNVector3(x: 1, y: 0.5, z: 1)
                //                self.sceneView.scene!.rootNode.addChildNode(bulletNode)
                //
                //                //apply impulse
                //                let impulse = SCNVector3(x: direction.x * Float(bulletImpulse), y: direction.y * Float(bulletImpulse), z: direction.z * Float(bulletImpulse))
                //                bulletNode.physicsBody?.applyForce(impulse, impulse: true)
                
                //update timestamp
                lastFired = now
            }
        }
        
    }
    
    let walkingMin = Float(-10)
    let walkingMax = Float(10)
    
    func handleWalking(){
        //get walk gesture translation
        let translation = walkGesture.translation(in: self.view)
        
        //create impulse vector for hero
        let angle = hero.presentation.rotation.w * hero.presentation.rotation.y
        
        var impulse = SCNVector3(x: max(walkingMin, min(walkingMax, Float(translation.x) / WalkSensetivity)),
            y: 0,
            z: max(walkingMin, min(walkingMax, Float(-translation.y) / WalkSensetivity)))
        impulse = SCNVector3(
            x: impulse.x * cos(angle) - impulse.z * sin(angle),
            y: 0,
            z: impulse.x * -sin(angle) - impulse.z * cos(angle)
        )
        hero.physicsBody?.applyForce(impulse, asImpulse: true)
    }
    
    func handleTap(_ gestureRecognize: UIGestureRecognizer) {
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // check what nodes are tapped
        let p = gestureRecognize.location(in: scnView)
        let hitResults = scnView.hitTest(p, options: nil)
        // check that we clicked on at least one object
        if hitResults.count > 0 {
            // retrieved the first clicked object
            let result: AnyObject! = hitResults[0]
            
            
            var currentNode = result.node
            while (((currentNode?.parent)) != nil) {
                currentNode = currentNode?.parent
                
                if (currentNode?.name == "enemy"){
                    print("Found Enemy!")
                    shootEnemy(currentNode!)
                    break
                }
            }
        }
    }
    
    
    func shootEnemy(_ enemy: SCNNode){
        //        if (result.node.name == "enemy"){
        
        //create impulse vector for hero
        let angle = hero.presentation.rotation.w * hero.presentation.rotation.y
        
        
        let aRand = Float((arc4random() % 50) + 1)
        var impulse = SCNVector3(x: max(walkingMin, min(walkingMax, Float((arc4random()%50) + 1) / WalkSensetivity)),
            y: 0,
            z: max(walkingMin, min(walkingMax, -aRand / WalkSensetivity)))
        
        impulse = SCNVector3(
            x: Float(enemy.presentation.position.x - hero.presentation.position.x) / 3,
            y: Float((arc4random() % 10) + 1),
            z: Float(enemy.presentation.position.z - hero.presentation.position.z) / 3
        )
        enemy.physicsBody?.applyForce(impulse, asImpulse: true)
        
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.3
        
        gunNode.constraints = [SCNLookAtConstraint(target: enemy)]
        
        SCNTransaction.commit()
    }
    
    
    
    
    
    override var shouldAutorotate : Bool {
        return true
    }
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
}
