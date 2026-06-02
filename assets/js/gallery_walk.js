import * as THREE from "three"
import {Socket, Presence} from "phoenix"

const MOVE_SPEED = 4.0
const BROADCAST_MS = 100
const FRAME_W = 1.4
const FRAME_H = 2.0
const EYE_HEIGHT = 1.6

function initGalleryWalk(root) {
  const galleryId = root.dataset.galleryId
  const guestName = root.dataset.guestName || "Guest"
  const guestColor = root.dataset.guestColor || "#ff5500"

  const canvas = root.querySelector("#gallery-walk-canvas")
  const hint = root.querySelector("#gallery-walk-hint")

  const scene = new THREE.Scene()
  scene.background = new THREE.Color(0x1a1a1a)
  scene.fog = new THREE.Fog(0x1a1a1a, 6, 40)

  const camera = new THREE.PerspectiveCamera(
    70,
    window.innerWidth / window.innerHeight,
    0.1,
    100
  )
  camera.position.set(0, EYE_HEIGHT, 4)

  const renderer = new THREE.WebGLRenderer({canvas, antialias: true})
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.setSize(window.innerWidth, window.innerHeight)

  const ambient = new THREE.AmbientLight(0xffffff, 0.65)
  const key = new THREE.DirectionalLight(0xffffff, 0.85)
  key.position.set(4, 10, 6)
  scene.add(ambient, key)

  const keys = {}
  const avatars = new Map()
  const loader = new THREE.TextureLoader()
  loader.crossOrigin = "anonymous"

  let roomSize = 12
  let galleryState = null
  let lastBroadcast = 0
  let yaw = 0
  let pointerLocked = false

  const socket = new Socket("/socket", {})
  socket.connect()

  const channel = socket.channel(`room:${galleryId}`, {name: guestName, color: guestColor})
  const presence = new Presence(channel)

  presence.onSync(() => syncAvatars())

  channel
    .join()
    .receive("ok", () => {})
    .receive("error", err => console.error("walk join failed", err))

  channel.on("gallery_state", state => {
    galleryState = state
    roomSize = Math.max(state.width || 12, state.depth || 12)
    buildRoom(scene, state)
    placeArtworks(scene, state.placements || [])
  })

  channel.on("presence_state", () => syncAvatars())
  channel.on("presence_diff", () => syncAvatars())

  function buildRoom(scene, state) {
    clearGroup(scene, "room")

    const group = new THREE.Group()
    group.name = "room"

    const wallColor = new THREE.Color(state.wall_color || "#f5f5f0")
    const floorMat = new THREE.MeshStandardMaterial({color: 0x2a2a2a, roughness: 0.9})
    const wallMat = new THREE.MeshStandardMaterial({color: wallColor, roughness: 0.85, side: THREE.DoubleSide})

    const half = roomSize / 2
    const wallH = 3.2

    const floor = new THREE.Mesh(new THREE.PlaneGeometry(roomSize, roomSize), floorMat)
    floor.rotation.x = -Math.PI / 2
    floor.receiveShadow = true
    group.add(floor)

    const wallGeo = new THREE.PlaneGeometry(roomSize, wallH)

    const back = new THREE.Mesh(wallGeo, wallMat)
    back.position.set(0, wallH / 2, -half)
    group.add(back)

    const front = new THREE.Mesh(wallGeo, wallMat)
    front.position.set(0, wallH / 2, half)
    front.rotation.y = Math.PI
    group.add(front)

    const left = new THREE.Mesh(wallGeo, wallMat)
    left.position.set(-half, wallH / 2, 0)
    left.rotation.y = Math.PI / 2
    group.add(left)

    const right = new THREE.Mesh(wallGeo, wallMat)
    right.position.set(half, wallH / 2, 0)
    right.rotation.y = -Math.PI / 2
    group.add(right)

    scene.add(group)
  }

  function placeArtworks(scene, placements) {
    clearGroup(scene, "artworks")
    const group = new THREE.Group()
    group.name = "artworks"

    for (const p of placements) {
      const scale = p.scale || 1
      const geo = new THREE.PlaneGeometry(FRAME_W * scale, FRAME_H * scale)
      const mat = new THREE.MeshStandardMaterial({color: 0x444444, side: THREE.DoubleSide})

      loader.load(
        p.artwork_url,
        tex => {
          tex.colorSpace = THREE.SRGBColorSpace
          mat.map = tex
          mat.needsUpdate = true
        },
        undefined,
        () => {}
      )

      const mesh = new THREE.Mesh(geo, mat)
      mesh.position.set(p.x, p.y, p.z)
      mesh.rotation.y = p.rotation_y || 0
      group.add(mesh)
    }

    scene.add(group)
  }

  function syncAvatars() {
    const seen = new Set()

    presence.list((id, {metas}) => {
      const meta = metas[0]
      if (!meta) return

      seen.add(id)
      let obj = avatars.get(id)

      if (!obj) {
        const color = new THREE.Color(meta.color || "#ff5500")
        const sphere = new THREE.Mesh(
          new THREE.SphereGeometry(0.35, 16, 16),
          new THREE.MeshStandardMaterial({color, emissive: color, emissiveIntensity: 0.25})
        )
        sphere.position.y = 0.35
        const label = makeLabel(meta.name || "Guest")
        label.position.y = 1.0
        obj = new THREE.Group()
        obj.add(sphere, label)
        scene.add(obj)
        avatars.set(id, obj)
      }

      obj.position.set(meta.x || 0, 0, meta.z || 0)
      obj.visible = true
    })

    for (const [id, obj] of avatars.entries()) {
      if (!seen.has(id)) {
        obj.visible = false
      }
    }
  }

  function makeLabel(text) {
    const size = 256
    const cvs = document.createElement("canvas")
    cvs.width = size
    cvs.height = 64
    const ctx = cvs.getContext("2d")
    ctx.fillStyle = "rgba(0,0,0,0.55)"
    ctx.fillRect(0, 0, size, 64)
    ctx.fillStyle = "#fff"
    ctx.font = "28px system-ui,sans-serif"
    ctx.textAlign = "center"
    ctx.fillText(text, size / 2, 42)

    const tex = new THREE.CanvasTexture(cvs)
    const mat = new THREE.SpriteMaterial({map: tex, transparent: true})
    const sprite = new THREE.Sprite(mat)
    sprite.scale.set(2.2, 0.55, 1)
    return sprite
  }

  function clearGroup(scene, name) {
    const existing = scene.getObjectByName(name)
    if (existing) {
      scene.remove(existing)
      disposeObject(existing)
    }
  }

  function disposeObject(obj) {
    obj.traverse(child => {
      if (child.geometry) child.geometry.dispose()
      if (child.material) {
        if (Array.isArray(child.material)) child.material.forEach(m => m.dispose())
        else child.material.dispose()
      }
    })
  }

  function broadcastPosition() {
    const now = performance.now()
    if (now - lastBroadcast < BROADCAST_MS) return
    lastBroadcast = now
    channel.push("move", {x: camera.position.x, z: camera.position.z})
  }

  function onResize() {
    camera.aspect = window.innerWidth / window.innerHeight
    camera.updateProjectionMatrix()
    renderer.setSize(window.innerWidth, window.innerHeight)
  }

  window.addEventListener("resize", onResize)

  window.addEventListener("keydown", e => {
    keys[e.code] = true
  })
  window.addEventListener("keyup", e => {
    keys[e.code] = false
  })

  canvas.addEventListener("click", () => {
    if (!pointerLocked) canvas.requestPointerLock()
  })

  document.addEventListener("pointerlockchange", () => {
    pointerLocked = document.pointerLockElement === canvas
    if (hint) hint.classList.toggle("hidden", pointerLocked)
  })

  document.addEventListener("mousemove", e => {
    if (!pointerLocked) return
    yaw -= e.movementX * 0.002
    camera.rotation.y = yaw
  })

  const clock = new THREE.Clock()

  function tick() {
    requestAnimationFrame(tick)
    const dt = clock.getDelta()

    if (pointerLocked) {
      const forward = new THREE.Vector3(0, 0, -1).applyEuler(camera.rotation)
      const right = new THREE.Vector3(1, 0, 0).applyEuler(camera.rotation)
      const move = new THREE.Vector3()

      if (keys.KeyW || keys.ArrowUp) move.add(forward)
      if (keys.KeyS || keys.ArrowDown) move.sub(forward)
      if (keys.KeyA || keys.ArrowLeft) move.sub(right)
      if (keys.KeyD || keys.ArrowRight) move.add(right)

      if (move.lengthSq() > 0) {
        move.normalize().multiplyScalar(MOVE_SPEED * dt)
        camera.position.add(move)
      }

      const bound = roomSize / 2 - 0.6
      camera.position.x = THREE.MathUtils.clamp(camera.position.x, -bound, bound)
      camera.position.z = THREE.MathUtils.clamp(camera.position.z, -bound, bound)
      camera.position.y = EYE_HEIGHT

      broadcastPosition()
    }

    renderer.render(scene, camera)
  }

  tick()

  return {
    destroy() {
      channel.leave()
      socket.disconnect()
      window.removeEventListener("resize", onResize)
      renderer.dispose()
    }
  }
}

document.addEventListener("DOMContentLoaded", () => {
  const root = document.getElementById("gallery-walk-root")
  if (root) initGalleryWalk(root)
})
