import {Socket, Presence} from "phoenix"

export const GalleryRoom = {
  mounted() {
    this.topic = `room:${this.el.dataset.galleryId}`
    this.guestName = this.el.dataset.guestName || "Guest"
    this.guestColor = this.el.dataset.guestColor || "#ff5500"

    this.socket = new Socket("/socket", {})
    this.socket.connect()

    this.channel = this.socket.channel(this.topic, {
      name: this.guestName,
      color: this.guestColor
    })

    this.channel
      .join()
      .receive("ok", () => {
        this.presence = new Presence(this.channel)
        this.presence.onSync(() => this.pushPresence())
      })
      .receive("error", resp => console.error("unable to join", resp))
  },

  destroyed() {
    if (this.channel) this.channel.leave()
    if (this.socket) this.socket.disconnect()
  },

  handleEvent(event, payload) {
    if (event === "chat_send") {
      this.channel.push("chat:new", {text: payload.text})
    }
  },

  listPresences() {
    if (!this.presence) return []

    return this.presence.list((id, {metas}) =>
      metas.map(meta => ({
        id: id,
        name: meta.name,
        color: meta.color,
        x: meta.x,
        z: meta.z
      }))
    )
  },

  pushPresence() {
    this.pushEvent("presence_update", {presences: this.listPresences()})
  }
}
