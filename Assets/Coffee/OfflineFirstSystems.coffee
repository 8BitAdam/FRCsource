  # ── Sidebar & Theme ────────────────────────────────────
openSidebar = ->
  document.getElementById('mySidebar').classList.add 'open'
  document.getElementById('myOverlay').style.display = 'block'
  document.body.style.overflow = 'hidden'
  return

closeSidebar = ->
  document.getElementById('mySidebar').classList.remove 'open'
  document.getElementById('myOverlay').style.display = 'none'
  document.body.style.overflow = ''
  return

html = document.documentElement
darkLabel = document.getElementById 'darkLabel'

applyTheme = (theme) ->
  html.setAttribute 'data-theme', theme
  localStorage.setItem 'frc-theme', theme
  if darkLabel
    darkLabel.textContent = if theme is 'dark' then 'Light' else 'Dark'
  if window.topoRedraw
    window.topoRedraw()
  return

toggleDark = ->
  applyTheme(if html.getAttribute('data-theme') is 'dark' then 'light' else 'dark')
  return

(->
  saved = localStorage.getItem 'frc-theme'
  prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  applyTheme(saved or (if prefersDark then 'dark' else 'light'))
  return
)()

# ── Reading Progress & TOC ─────────────────────────────
progressFill = document.getElementById 'readingProgress'
sections = document.querySelectorAll '.article-body h2[id]'
tocItems = document.querySelectorAll '.toc-list li[id]'

updateProgress = ->
  scrollTop = window.scrollY
  docHeight = document.documentElement.scrollHeight - window.innerHeight
  progress = if docHeight > 0 then Math.round((scrollTop / docHeight) * 100) else 0
  if progressFill
    progressFill.style.width = progress + '%'
  
  activeId = null
  sections.forEach (sec) ->
    if scrollTop >= sec.offsetTop - 120
      activeId = sec.id
    return
    
  tocItems.forEach (item) ->
    item.classList.remove 'active'
    if item.id is 'toc-' + activeId
      item.classList.add 'active'
    return
  return

window.addEventListener 'scroll', updateProgress, { passive: true }
updateProgress()

# ══════════════════════════════════════════════════════
#    TOPOLOGY DIAGRAM ENGINE
# ══════════════════════════════════════════════════════
(->
  canvas = document.getElementById 'topoCanvas'
  ctx = canvas.getContext '2d'
  logEl = document.getElementById 'topoLog'
  statusDot = document.getElementById 'topoStatusDot'
  statusText = document.getElementById 'topoStatusText'

  # ── State ──
  state =
    scoutsOnline: [true, true, true, true, true, true] # 6 scouts
    hubOnline: true
    internetOnline: true
    packets: [] # animated data packets
    time: 0

  # ── Layout (percentages of canvas, recalculated on resize) ──
  W = undefined
  H = undefined
  nodes = undefined

  recalcLayout = ->
    W = canvas.offsetWidth
    H = 300
    canvas.width = W
    canvas.height = H

    scoutX = W * 0.13
    hubX = W * 0.50
    netX = W * 0.87

    # 6 scouts vertically distributed
    scoutCount = 6
    topPad = H * 0.12
    botPad = H * 0.12
    step = (H - topPad - botPad) / (scoutCount - 1)

    nodes =
      scouts: [0...scoutCount].map (i) ->
        x: scoutX
        y: topPad + i * step
        r: 18
        label: "Scout #{i + 1}"
        color: '#38bdf8'
        offline: false
        pending: 0 # submissions pending transfer
      hub:
        x: hubX
        y: H / 2
        r: 28
        label: 'Hub'
        color: '#34d399'
        offline: false
      internet:
        x: netX
        y: H / 2
        r: 22
        label: 'TBA / Net'
        color: '#f59e0b'
        offline: false
    return

  isDark = ->
    document.documentElement.getAttribute('data-theme') is 'dark'

  # ── Drawing ──
  drawNode = (n, offline, label) ->
    alpha = if offline then 0.25 else 1
    ctx.globalAlpha = alpha

    # glow
    if not offline
      grad = ctx.createRadialGradient(n.x, n.y, n.r * 0.5, n.x, n.y, n.r * 2.2)
      grad.addColorStop 0, n.color + '30'
      grad.addColorStop 1, n.color + '00'
      ctx.beginPath()
      ctx.arc n.x, n.y, n.r * 2.2, 0, Math.PI * 2
      ctx.fillStyle = grad
      ctx.fill()

    # circle
    ctx.beginPath()
    ctx.arc n.x, n.y, n.r, 0, Math.PI * 2
    ctx.fillStyle = if offline then '#334155' else n.color + '22'
    ctx.fill()
    ctx.strokeStyle = if offline then '#334155' else n.color
    ctx.lineWidth = 2
    ctx.stroke()

    # icon text
    ctx.fillStyle = if offline then '#475569' else n.color
    ctx.font = "bold #{Math.round(n.r * 0.55)}px \"Barlow Condensed\", sans-serif"
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    icon = if label.startsWith('Scout') then '📱' else (if label is 'Hub' then '💻' else '☁️')
    ctx.font = "#{Math.round(n.r * 0.75)}px serif"
    ctx.fillText icon, n.x, n.y

    # label
    ctx.font = "600 #{Math.max(9, Math.round(n.r * 0.55))}px \"Barlow\", sans-serif"
    ctx.fillStyle = if isDark() then (if offline then '#334155' else '#94a3b8') else (if offline then '#94a3b8' else '#475569')
    ctx.textAlign = 'center'
    ctx.textBaseline = 'top'
    ctx.fillText label, n.x, n.y + n.r + 4

    ctx.globalAlpha = 1
    return

  drawEdge = (a, b, aOffline, bOffline, dashed) ->
    active = not aOffline and not bOffline
    ctx.beginPath()
    ctx.moveTo a.x, a.y
    ctx.lineTo b.x, b.y
    ctx.strokeStyle = if active then (if isDark() then '#1e3a5f' else '#cbd5e1') else (if isDark() then '#1a2332' else '#e2e8f0')
    ctx.lineWidth = if active then 1.5 else 1
    if dashed
      ctx.setLineDash [6, 4]
    else
      ctx.setLineDash []
    ctx.stroke()
    ctx.setLineDash []
    return

  drawPacket = (p) ->
    t = p.progress
    x = p.x0 + (p.x1 - p.x0) * t
    y = p.y0 + (p.y1 - p.y0) * t
    ctx.beginPath()
    ctx.arc x, y, 5, 0, Math.PI * 2
    ctx.fillStyle = p.color
    ctx.fill()

    # trail
    ctx.beginPath()
    tx = p.x0 + (p.x1 - p.x0) * Math.max(0, t - 0.15)
    ty = p.y0 + (p.y1 - p.y0) * Math.max(0, t - 0.15)
    ctx.moveTo tx, ty
    ctx.lineTo x, y
    ctx.strokeStyle = p.color + '60'
    ctx.lineWidth = 2.5
    ctx.stroke()
    return

  # ── Pending indicator dots on scouts ──
  drawPendingDots = (scout, n) ->
    if n <= 0 or scout.offline
      return
    for i in [0...Math.min(n, 5)]
      ctx.beginPath()
      ctx.arc scout.x + scout.r - 4, scout.y - scout.r + 4 + i * 7, 3, 0, Math.PI * 2
      ctx.fillStyle = '#f59e0b'
      ctx.fill()
    return

  draw = ->
    ctx.clearRect 0, 0, W, H

    # background is CSS, canvas is transparent
    # draw edges
    nodes.scouts.forEach (s, i) ->
      offline = state.scoutsOnline[i] is false or state.hubOnline is false
      drawEdge s, nodes.hub, not state.scoutsOnline[i], not state.hubOnline, false
      return
      
    drawEdge nodes.hub, nodes.internet, not state.hubOnline, not state.internetOnline, true

    # draw nodes
    nodes.scouts.forEach (s, i) ->
      drawNode s, not state.scoutsOnline[i], "Scout #{i + 1}"
      if state.scoutsOnline[i]
        drawPendingDots s, s.pending
      return
      
    drawNode nodes.hub, not state.hubOnline, 'Hub'
    drawNode nodes.internet, not state.internetOnline, 'TBA / Net'

    # packets
    state.packets.forEach (p) ->
      drawPacket p
      return
    return

  # ── Animation loop ──
  lastTs = 0
  loop_anim = (ts) ->
    dt = Math.min((ts - lastTs) / 1000, 0.05)
    lastTs = ts
    state.time += dt

    # advance packets
    state.packets = state.packets.filter (p) ->
      p.progress += dt * p.speed
      if p.progress >= 1
        if p.onComplete then p.onComplete()
        return false
      return true

    draw()
    requestAnimationFrame loop_anim
    return

  # ── Logging ──
  log = (msg, type = 'info') ->
    mins = String(Math.floor(state.time / 60)).padStart 2, '0'
    secs = String(Math.floor(state.time % 60)).padStart 2, '0'
    lines = logEl.querySelectorAll '.log-line'
    if lines.length >= 3
      lines[0].remove()
    div = document.createElement 'div'
    div.className = 'log-line'
    div.innerHTML = "<span class=\"log-ts\">#{mins}:#{secs}</span><span class=\"log-#{type}\">#{msg}</span>"
    logEl.appendChild div
    return

  updateStatus = ->
    offline = state.scoutsOnline.filter((s) -> not s).length
    if not state.hubOnline
      statusDot.style.background = '#f87171'
      statusDot.style.animationPlayState = 'running'
      statusText.textContent = '⚠ Hub offline — analysis unavailable'
    else if offline > 0
      statusDot.style.background = '#f59e0b'
      statusText.textContent = "#{offline} scout(s) offline — data queued"
    else if not state.internetOnline
      statusDot.style.background = '#f59e0b'
      statusText.textContent = 'No internet — TBA unavailable, scouting OK'
    else
      statusDot.style.background = '#34d399'
      statusText.textContent = 'All systems nominal'
    return

  # ── Packet helpers ──
  firePacket = (fromNode, toNode, color, speed, onComplete) ->
    state.packets.push
      x0: fromNode.x
      y0: fromNode.y
      x1: toNode.x
      y1: toNode.y
      color: color
      speed: speed or 1.2
      progress: 0
      onComplete: onComplete
    return

  # ── Controls ──
  scoutToggleIdx = 0

  window.topoSendData = ->
    # pick a random online scout
    online = nodes.scouts.map((s, i) -> i).filter((i) -> state.scoutsOnline[i])
    if not online.length
      log 'All scouts offline — no data to send.', 'warn'
      return
    if not state.hubOnline
      log 'Hub offline — submission queued on device.', 'warn'
      idx = online[Math.floor(Math.random() * online.length)]
      nodes.scouts[idx].pending++
      return
    idx = online[Math.floor(Math.random() * online.length)]
    scout = nodes.scouts[idx]
    firePacket scout, nodes.hub, '#38bdf8', 1.4, ->
      log "Scout #{idx + 1} → Hub: submission received. (#{if scout.pending > 0 then scout.pending-- + ' queued transferred' else 'queue clear'})", 'ok'
      if state.internetOnline and not state.packets.some((p) -> p.color is '#f59e0b')
        setTimeout (->
          if state.hubOnline and state.internetOnline
            firePacket nodes.hub, nodes.internet, '#f59e0b', 1.0, ->
              log 'Hub → TBA: score cross-reference OK.', 'ok'
              return
          return
        ), 300
      return
    log "Scout #{idx + 1}: submitting data packet...", 'info'
    return

  window.topoToggleScout = ->
    # cycle through scouts
    scoutToggleIdx = scoutToggleIdx % 6
    state.scoutsOnline[scoutToggleIdx] = not state.scoutsOnline[scoutToggleIdx]
    now = state.scoutsOnline[scoutToggleIdx]
    if not now
      log "Scout #{scoutToggleIdx + 1} went offline — #{nodes.scouts[scoutToggleIdx].pending} submissions queued.", 'warn'
    else
      pending = nodes.scouts[scoutToggleIdx].pending
      log "Scout #{scoutToggleIdx + 1} back online.#{if pending > 0 then " Flushing #{pending} queued submission(s)..." else ''}", 'ok'
      if pending > 0 and state.hubOnline
        ((currentIdx, currentPending) ->
          firePacket nodes.scouts[currentIdx], nodes.hub, '#38bdf8', 1.0, ->
            log "Scout #{currentIdx + 1}: queue flushed — #{currentPending} submission(s) delivered.", 'ok'
            nodes.scouts[currentIdx].pending = 0
            return
        )(scoutToggleIdx, pending)
    
    scoutToggleIdx++
    if scoutToggleIdx >= 6
      scoutToggleIdx = 0
    updateStatus()
    return

  window.topoToggleInternet = ->
    # Patched: force a clean restore if internet is currently offline
    if not state.internetOnline
      state.internetOnline = true
      log 'Internet restored — TBA cross-reference resuming.', 'ok'
    else
      state.internetOnline = false
      log 'Venue WiFi down — TBA unavailable. Scouting continues normally.', 'warn'
    updateStatus()
    draw()
    return

  window.topoRestoreInternet = ->
    state.internetOnline = true
    log 'Internet restored — TBA cross-reference resuming.', 'ok'
    updateStatus()
    draw()
    return

  window.topoHubFail = ->
    if not state.hubOnline
      log 'Hub already offline.', 'warn'
      return
    state.hubOnline = false
    state.packets = state.packets.filter (p) -> p.color isnt '#34d399'
    # queue pending on all online scouts
    nodes.scouts.forEach (s, i) ->
      if state.scoutsOnline[i]
        s.pending++
      return
    log '⚠ Hub device failure! Scouts queuing data locally. Deploy backup hub.', 'err'
    updateStatus()
    return

  window.topoReset = ->
    state.scoutsOnline.fill true
    state.hubOnline = true
    state.internetOnline = true
    state.packets = []
    nodes.scouts.forEach (s) ->
      s.pending = 0
      return
    scoutToggleIdx = 0
    log 'System reset — all nodes online.', 'ok'
    updateStatus()
    return

  window.topoRedraw = ->
    draw()
    return

  # ── Resize handler ──
  resize = ->
    recalcLayout()
    draw()
    return
    
  window.addEventListener 'resize', resize

  # ── Boot ──
  recalcLayout()
  requestAnimationFrame (ts) ->
    lastTs = ts
    loop_anim ts
    return
  updateStatus()
  return
)()
