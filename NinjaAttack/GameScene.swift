import SpriteKit


func +(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func -(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func *(point: CGPoint, scalar: CGFloat) -> CGPoint {
  return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func /(point: CGPoint, scalar: CGFloat) -> CGPoint {
  return CGPoint(x: point.x / scalar, y: point.y / scalar)
}

#if !(arch(x86_64) || arch(arm64))
  func sqrt(a: CGFloat) -> CGFloat {
    return CGFloat(sqrtf(Float(a)))
  }
#endif

extension CGPoint {
  func length() -> CGFloat {
    return sqrt(x*x + y*y)
  }
  
  func normalized() -> CGPoint {
    return self / length()
  }
}

struct PhysicsCategory {
  static let none      : UInt32 = 0
  static let all       : UInt32 = UInt32.max
  static let monster   : UInt32 = 0b1       // 1
  static let projectile: UInt32 = 0b10      // 2
}

class GameScene: SKScene {
  
  let player = SKSpriteNode(imageNamed: "player")
  var monstersDestroyed = 0
  override func didMove(to view: SKView) {
    backgroundColor = SKColor.white
    player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5) //Sprite position
    addChild(player) //Make sprite appear on the
    physicsWorld.gravity = .zero
    physicsWorld.contactDelegate = self //set the scene as the                                       //delegate to be notified                                    //when 2 physics bodies collide
    run(SKAction.repeatForever(
         SKAction.sequence([
           SKAction.run(addMonster),
           SKAction.wait(forDuration: 1.0)
       ])
       ))
    let backgroundMusic = SKAudioNode(fileNamed: "background-music-aac.caf")
    backgroundMusic.autoplayLooped = true
    addChild(backgroundMusic)
  }
    func random() -> CGFloat{
      return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
    }
    
    func random(min: CGFloat, max: CGFloat) -> CGFloat{
      return random() * (max-min) + min
    }
    
    func addMonster(){
      
      //Create sprite
      let monster = SKSpriteNode(imageNamed: "monster")
      
      //Determine where to spawn the monster along Y axis
      let actualY = random(min: monster.size.height/2, max: size.height - monster.size.height/2)
      
      //Position the monster slightly off-screen along the right edge and along a random position along the Y axis as calculated above
      monster.position = CGPoint(x: size.width + monster.size.width/2,y:actualY)
      
      //Add the monster to the scene
      addChild(monster)
      //Create physic body for the sprite: a rectangle same size as the sprite
      monster.physicsBody = SKPhysicsBody(rectangleOf: monster.size)
      //Set the sprite to be dynamic, controlled by player
      monster.physicsBody?.isDynamic = true
      //Set category bit mask to monsterCategory
      monster.physicsBody?.categoryBitMask = PhysicsCategory.monster
      //indicate what categories of objects this objt should notaify the contact listener when they intersect
      monster.physicsBody?.contactTestBitMask = PhysicsCategory.projectile
      //collision setting: projectile dont collise with monster
      monster.physicsBody?.collisionBitMask = PhysicsCategory.none
      //Determine the speed of the monster
      let actualDuration = random(min: CGFloat(2.0), max: CGFloat(4.0))
      
      //Create the actions
      let actionMove = SKAction.move(to: CGPoint(x: -monster.size.width/2, y: actualY), duration: TimeInterval(actualDuration))
      
      let actionMoveDone = SKAction.removeFromParent()
      
      //if lose
      let loseAction = SKAction.run() { [weak self] in
        guard let `self` = self else { return }
        let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
        let gameOverScene = GameOverScene(size: self.size, won: false)
        self.view?.presentScene(gameOverScene, transition: reveal)
      }
      monster.run(SKAction.sequence([actionMove, loseAction, actionMoveDone]))

    }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else{
      return
    }
    run(SKAction.playSoundFileNamed("pew-pew-lei.caf", waitForCompletion: false))
    let touchLocation = touch.location(in: self)
    
    //Set up initial location of projectile
    let projectile = SKSpriteNode(imageNamed: "projectile")
    projectile.position = player.position

    projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2)
    projectile.physicsBody?.isDynamic = true
    projectile.physicsBody?.categoryBitMask = PhysicsCategory.projectile
    projectile.physicsBody?.contactTestBitMask = PhysicsCategory.none
    projectile.physicsBody?.usesPreciseCollisionDetection = true
    
    //Determine offset of location to projectile
    let offset = touchLocation - projectile.position
    
    //Bail out if you are shooting down or backwards
    if offset.x < 0 {return}
    
    //Ok to add now
    addChild(projectile)
    
    //Get the direction of where to shoot
    let direction = offset.normalized()
    
    //Make it shoot far enough to be guaranteed off screen
    let shootAmount = direction * 1000
    
    //Add the shoot amount to the current position
    let realDest = shootAmount + projectile.position
    
    //Create the actions
    let actionMove = SKAction.move(to: realDest, duration: 2.0)
    let actionMoveDone = SKAction.removeFromParent()
    projectile.run(SKAction.sequence([actionMove, actionMoveDone]))
  }
  func projectileDidCollideWithMonster(projectile:SKSpriteNode, monster: SKSpriteNode){
    print("Hit")
    projectile.removeFromParent()
    monster.removeFromParent()
    monstersDestroyed += 1
    
    //Win when monstersDestroyed > 30
    if monstersDestroyed > 30 {
      let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
      let gameOverScene = GameOverScene(size: self.size, won: true)
      view?.presentScene(gameOverScene, transition: reveal)
    }
  }
  }

extension GameScene: SKPhysicsContactDelegate{
  func didBegin(_ contact: SKPhysicsContact){
    var firstBody: SKPhysicsBody
    var secondBody: SKPhysicsBody
    if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask{
        firstBody = contact.bodyA
        secondBody = contact.bodyB
  }else{
      firstBody = contact.bodyB
      secondBody = contact.bodyA
  }
    if((firstBody.categoryBitMask & PhysicsCategory.monster != 0) &&
      (secondBody.categoryBitMask & PhysicsCategory.projectile != 0)){
      if let monster = firstBody.node as? SKSpriteNode,
        let projectile = secondBody.node as? SKSpriteNode{
        projectileDidCollideWithMonster(projectile: projectile, monster: monster)
      }
    }
  }
}

