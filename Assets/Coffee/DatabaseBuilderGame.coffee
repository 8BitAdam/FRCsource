tables = []
activeTab = null
currentTab = 'sql'
tableIdCounter = 0
fieldIdCounter = 0

TYPES = [
  'INTEGER'
  'TEXT'
  'REAL'
  'BOOLEAN'
  'DATE'
  'TIMESTAMP'
]
COLORS = [
  '#f0abfc'
  '#93c5fd'
  '#6ee7b7'
  '#fcd34d'
  '#fca5a5'
  '#a5b4fc'
  '#67e8f9'
  '#86efac'
]

# ── DOM refs ───────────────────────────────────────────────
tabsEl = document.getElementById 'table-tabs'
cardsEl = document.getElementById 'table-cards-container'
sqlEl = document.getElementById 'sql-output'
erCanvas = document.getElementById 'er-canvas'
outputEl = document.getElementById 'output-content'
scoreT = document.getElementById 'score-tables'
scoreF = document.getElementById 'score-fields'
scoreR = document.getElementById 'score-relations'
hintEl = document.getElementById 'hint-text'
nf1 = document.getElementById 'nf1-dot'
nf2 = document.getElementById 'nf2-dot'
nf3 = document.getElementById 'nf3-dot'
nfLabel = document.getElementById 'nf-label'

# ── Table CRUD ─────────────────────────────────────────────
addTable = (name, fields) ->
  id = ++tableIdCounter
  color = COLORS[(tables.length) % COLORS.length]
  tbl =
    id: id
    name: name or "Table#{id}"
    color: color
    fields: fields or [
      {
        id: ++fieldIdCounter
        name: 'id'
        type: 'INTEGER'
        isPK: true
        fk: ''
      }
    ]
  tables.push tbl
  setActive id
  render()
  return

deleteTable = (id) ->
  tables = tables.filter (t) -> t.id isnt id
  # Remove any FK references to this table
  tables.forEach (t) ->
    t.fields.forEach (f) ->
      if f.fk
        refTableId = f.fk.split('.')[0]
        refTable = getTableById(refTableId)
        refName = refTable?.name ? '__GONE__'
        if f.fk.startsWith(refName)
          f.fk = ''
      return
    return
  cleanOrphanFKs()
  if activeTab is id
    activeTab = if tables.length then tables[tables.length - 1].id else null
  render()
  return

addField = (tableId) ->
  tbl = getTableById(tableId)
  return unless tbl
  tbl.fields.push
    id: ++fieldIdCounter
    name: 'field'
    type: 'TEXT'
    isPK: false
    fk: ''
  render()
  return

deleteField = (tableId, fieldId) ->
  tbl = getTableById(tableId)
  return unless tbl
  tbl.fields = tbl.fields.filter (f) -> f.id isnt fieldId
  render()
  return

getTableById = (id) ->
  tables.find (t) -> t.id is id

setActive = (id) ->
  activeTab = id
  return

cleanOrphanFKs = ->
  validRefs = new Set()
  tables.forEach (t) ->
    t.fields.forEach (f) ->
      if f.isPK
        validRefs.add "#{t.name}.#{f.name}"
      return
    return
  tables.forEach (t) ->
    t.fields.forEach (f) ->
      if f.fk and not validRefs.has(f.fk)
        f.fk = ''
      return
    return
  return

# ── Render ─────────────────────────────────────────────────
render = ->
  renderTabs()
  renderCards()
  renderOutput()
  renderScore()
  return

renderTabs = ->
  tabsEl.innerHTML = ''
  tables.forEach (tbl) ->
    btn = document.createElement 'button'
    btn.className = 'tbl-btn' + (if tbl.id is activeTab then ' active' else '')
    btn.textContent = tbl.name
    btn.style.borderColor = if tbl.id is activeTab then tbl.color else ''
    btn.style.color = if tbl.id is activeTab then tbl.color else ''
    btn.onclick = ->
      setActive tbl.id
      render()
      return
    tabsEl.appendChild btn
    return
  return

renderCards = ->
  cardsEl.innerHTML = ''
  activeTbl = tables.find (t) -> t.id is activeTab
  if not activeTbl
    cardsEl.innerHTML = '<div style="color:#475569;font-family:\'JetBrains Mono\',monospace;font-size:0.75rem;padding:1rem;">No tables yet. Click "+ New Table" to begin.</div>'
    return

  # Only show the active table card for clarity
  card = buildCard(activeTbl)
  cardsEl.appendChild card
  return

buildCard = (tbl) ->
  card = document.createElement 'div'
  card.className = 'schema-table-card'

  # Header
  hdr = document.createElement 'div'
  hdr.className = 'table-card-header'
  hdr.style.borderLeft = "3px solid #{tbl.color}"

  nameInput = document.createElement 'input'
  nameInput.value = tbl.name
  nameInput.title = 'Table name'
  nameInput.oninput = ->
    tbl.name = nameInput.value
    renderOutput()
    renderScore()
    renderTabs()
    return

  delBtn = document.createElement 'button'
  delBtn.className = 'tbl-delete-btn'
  delBtn.innerHTML = '<i class="fa fa-trash"></i>'
  delBtn.title = 'Delete table'
  delBtn.onclick = ->
    deleteTable tbl.id
    return

  hdr.appendChild nameInput
  hdr.appendChild delBtn
  card.appendChild hdr

  # Fields
  fieldsDiv = document.createElement 'div'
  fieldsDiv.className = 'table-fields'

  # Build FK options from all PKs in other tables
  fkOptions = []
  tables.forEach (t) ->
    return if t.id is tbl.id
    t.fields.filter((f) -> f.isPK).forEach (f) ->
      fkOptions.push "#{t.name}.#{f.name}"
      return
    return

  tbl.fields.forEach (field) ->
    row = document.createElement 'div'
    row.className = 'field-row'

    # PK badge
    pkEl = document.createElement 'span'
    pkEl.className = 'field-pk'
    pkEl.title = if field.isPK then 'Primary Key' else 'Click to toggle PK'
    pkEl.textContent = if field.isPK then 'PK' else '·'
    pkEl.style.cursor = 'pointer'
    pkEl.style.color = if field.isPK then '#fbbf24' else (if field.fk then '#fcd34d' else '#334155')
    if field.fk
      pkEl.textContent = 'FK'
    pkEl.onclick = ->
      if not field.fk
        field.isPK = not field.isPK
        render()
      return

    # Name
    nameIn = document.createElement 'input'
    nameIn.className = 'field-name-input'
    nameIn.value = field.name
    nameIn.oninput = ->
      field.name = nameIn.value
      renderOutput()
      renderScore()
      return

    # Type
    typeSelect = document.createElement 'select'
    typeSelect.className = 'field-type-select'
    TYPES.forEach (t) ->
      opt = document.createElement 'option'
      opt.value = t
      opt.textContent = t
      if t is field.type
        opt.selected = true
      typeSelect.appendChild opt
      return
    typeSelect.onchange = ->
      field.type = typeSelect.value
      renderOutput()
      return

    # FK select
    fkSelect = document.createElement 'select'
    fkSelect.className = 'field-fk-select'
    noFk = document.createElement 'option'
    noFk.value = ''
    noFk.textContent = 'no FK'
    fkSelect.appendChild noFk
    fkOptions.forEach (ref) ->
      opt = document.createElement 'option'
      opt.value = ref
      opt.textContent = '→' + ref
      if ref is field.fk
        opt.selected = true
      fkSelect.appendChild opt
      return
    fkSelect.onchange = ->
      field.fk = fkSelect.value
      if field.fk
        field.isPK = false
      render()
      return

    # Delete field btn
    delF = document.createElement 'button'
    delF.className = 'field-delete-btn'
    delF.innerHTML = '×'
    delF.onclick = ->
      deleteField tbl.id, field.id
      return

    row.appendChild pkEl
    row.appendChild nameIn
    row.appendChild typeSelect
    if not field.isPK
      row.appendChild fkSelect
    row.appendChild delF
    fieldsDiv.appendChild row
    return

  # Add field button
  addFBtn = document.createElement 'button'
  addFBtn.className = 'add-field-btn'
  addFBtn.innerHTML = '<i class="fa fa-plus" style="font-size:0.6rem;"></i> add field'
  addFBtn.onclick = ->
    addField tbl.id
    return
  fieldsDiv.appendChild addFBtn

  card.appendChild fieldsDiv
  return card

# ── SQL generation ─────────────────────────────────────────
generateSQL = ->
  if not tables.length
    return '<span class="sql-comment">-- No tables defined yet.\n-- Click "+ New Table" to start building your schema.</span>'

  sql = ''
  tables.forEach (tbl, i) ->
    if i > 0
      sql += '\n\n'
    sql += "<span class=\"sql-comment\">-- #{tbl.name} table</span>\n"
    sql += "<span class=\"sql-keyword\">CREATE TABLE</span> <span class=\"sql-table\">#{tbl.name}</span> (\n"

    lines = []
    pks = tbl.fields.filter((f) -> f.isPK).map((f) -> f.name)

    tbl.fields.forEach (f) ->
      line = "  <span class=\"sql-field\">#{f.name}</span>  <span class=\"sql-type\">#{f.type}</span>"
      if f.isPK and tbl.fields.filter((x) -> x.isPK).length is 1
        line += ' <span class="sql-pk">PRIMARY KEY</span>'
      if f.isPK and f.type is 'INTEGER'
        line += ' <span class="sql-keyword">AUTOINCREMENT</span>'
      if not f.isPK and not f.fk
        line += ' <span class="sql-keyword">NOT NULL</span>'
      lines.push line
      return

    # Composite PK
    if pks.length > 1
      lines.push "  <span class=\"sql-pk\">PRIMARY KEY</span> (<span class=\"sql-field\">#{pks.join(', ')}</span>)"

    # FK constraints
    tbl.fields.filter((f) -> f.fk).forEach (f) ->
      [refTable, refField] = f.fk.split('.')
      lines.push "  <span class=\"sql-keyword\">FOREIGN KEY</span> (<span class=\"sql-field\">#{f.name}</span>) <span class=\"sql-keyword\">REFERENCES</span> <span class=\"sql-fk\">#{refTable}</span>(<span class=\"sql-field\">#{refField}</span>)"
      return

    sql += lines.join(',\n') + '\n);\n'

    # Indexes for FK fields
    tbl.fields.filter((f) -> f.fk).forEach (f) ->
      sql += "<span class=\"sql-keyword\">CREATE INDEX</span> idx_#{tbl.name.toLowerCase()}_#{f.name} <span class=\"sql-keyword\">ON</span> <span class=\"sql-table\">#{tbl.name}</span>(<span class=\"sql-field\">#{f.name}</span>);\n"
      return
    return

  return sql

# ── ER Diagram ─────────────────────────────────────────────
renderER = ->
  ctx = erCanvas.getContext '2d'
  W = erCanvas.width = erCanvas.offsetWidth or 400
  H = erCanvas.height = erCanvas.offsetHeight or 360

  ctx.clearRect 0, 0, W, H
  ctx.fillStyle = '#0f172a'
  ctx.fillRect 0, 0, W, H

  if not tables.length
    ctx.fillStyle = '#475569'
    ctx.font = '12px JetBrains Mono, monospace'
    ctx.textAlign = 'center'
    ctx.fillText 'No tables to visualize.', W / 2, H / 2
    return

  # Layout tables in a circle
  cx = W / 2
  cy = H / 2
  r = Math.min(W, H) * 0.33
  positions = {}
  BOX_W = 120
  BOX_H = 28

  tables.forEach (tbl, i) ->
    angle = (i / tables.length) * 2 * Math.PI - Math.PI / 2
    positions[tbl.id] =
      x: cx + r * Math.cos(angle)
      y: cy + r * Math.sin(angle)
    return

  # Draw FK relationship lines first
  tables.forEach (tbl) ->
    tbl.fields.filter((f) -> f.fk).forEach (f) ->
      [refName] = f.fk.split('.')
      refTbl = tables.find (t) -> t.name is refName
      return unless refTbl
      from = positions[tbl.id]
      to = positions[refTbl.id]

      ctx.beginPath()
      ctx.moveTo from.x, from.y

      # Curved line
      mx = (from.x + to.x) / 2
      my = (from.y + to.y) / 2 - 20
      ctx.quadraticCurveTo mx, my, to.x, to.y

      ctx.strokeStyle = '#fcd34d66'
      ctx.lineWidth = 1.5
      ctx.setLineDash [4, 3]
      ctx.stroke()
      ctx.setLineDash []

      # Arrow head at destination
      angle = Math.atan2(to.y - my, to.x - mx)
      ctx.beginPath()
      ctx.moveTo to.x, to.y
      ctx.lineTo to.x - 10 * Math.cos(angle - 0.4), to.y - 10 * Math.sin(angle - 0.4)
      ctx.lineTo to.x - 10 * Math.cos(angle + 0.4), to.y - 10 * Math.sin(angle + 0.4)
      ctx.closePath()
      ctx.fillStyle = '#fcd34d'
      ctx.fill()

      # Label the FK field
      ctx.font = '9px JetBrains Mono, monospace'
      ctx.fillStyle = '#fcd34d99'
      ctx.textAlign = 'center'
      ctx.fillText f.name, (from.x + to.x) / 2, (from.y + to.y) / 2 - 8
      return
    return

  # Draw table boxes
  tables.forEach (tbl) ->
    pos = positions[tbl.id]
    x = pos.x - BOX_W / 2
    y = pos.y - BOX_H / 2

    # Shadow
    ctx.shadowColor = tbl.color + '44'
    ctx.shadowBlur = 12
    ctx.fillStyle = '#1e293b'
    ctx.beginPath()
    ctx.roundRect x, y, BOX_W, BOX_H, 6
    ctx.fill()
    ctx.shadowBlur = 0

    # Border
    ctx.strokeStyle = tbl.color
    ctx.lineWidth = 1.5
    ctx.beginPath()
    ctx.roundRect x, y, BOX_W, BOX_H, 6
    ctx.stroke()

    # Table name
    ctx.fillStyle = tbl.color
    ctx.font = 'bold 11px JetBrains Mono, monospace'
    ctx.textAlign = 'center'
    ctx.fillText tbl.name, pos.x, pos.y + 4

    # Field count badge
    ctx.fillStyle = '#475569'
    ctx.font = '9px JetBrains Mono, monospace'
    ctx.fillText "#{tbl.fields.length} fields", pos.x, pos.y + BOX_H + 12
    return
  return

# ── Output switcher ────────────────────────────────────────
renderOutput = ->
  if currentTab is 'sql'
    sqlEl.style.display = 'block'
    erCanvas.style.display = 'none'
    sqlEl.innerHTML = generateSQL()
  else
    sqlEl.style.display = 'none'
    erCanvas.style.display = 'block'
    setTimeout renderER, 10
  return

switchTab = (tab, el) ->
  currentTab = tab
  document.querySelectorAll('.output-tab').forEach (t) -> t.classList.remove 'active'
  el.classList.add 'active'
  copyBtn = document.getElementById 'copy-btn'
  if copyBtn
    copyBtn.style.display = if tab is 'sql' then '' else 'none'
  renderOutput()
  return

# ── Score & NF ─────────────────────────────────────────────
renderScore = ->
  totalFields = tables.reduce ((s, t) -> s + t.fields.length), 0
  totalRelations = tables.reduce ((s, t) -> s + t.fields.filter((f) -> f.fk).length), 0

  scoreT.textContent = tables.length
  scoreF.textContent = totalFields
  scoreR.textContent = totalRelations

  # NF checks (heuristic, not rigorous)
  has1NF = tables.length > 0 and tables.every (t) -> t.fields.length > 0
  has2NF = has1NF and tables.every (t) -> t.fields.some (f) -> f.isPK
  has3NF = has2NF and totalRelations > 0 and tables.length >= 2

  nf1.classList.toggle 'achieved', has1NF
  nf2.classList.toggle 'achieved', has2NF
  nf3.classList.toggle 'achieved', has3NF

  nfReached = if has3NF then '3NF' else (if has2NF then '2NF' else (if has1NF then '1NF' else 'Unnormalized'))
  nfLabel.textContent = nfReached

  # Hints
  if not tables.length
    hintEl.textContent = 'Add a table to get started'
  else if not has2NF
    hintEl.textContent = 'Tip: add a PRIMARY KEY to each table'
  else if not has3NF
    hintEl.textContent = 'Tip: link tables with a FOREIGN KEY to reach 3NF'
  else
    hintEl.textContent = "Schema looks good! #{tables.length} table#{if tables.length > 1 then 's' else ''} defined."
  return

# ── Copy SQL ───────────────────────────────────────────────
copySql = ->
  plain = sqlEl.textContent
  navigator.clipboard.writeText(plain).then ->
    btn = document.getElementById 'copy-btn'
    btn.textContent = 'Copied!'
    setTimeout (-> btn.textContent = 'Copy SQL'), 1500
    return
  return

# ── Seed data ──────────────────────────────────────────────
loadSeed = ->
  clearAll true

  # Teams
  addTable 'Teams', [
    {
      id: ++fieldIdCounter
      name: 'team_number'
      type: 'INTEGER'
      isPK: true
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'nickname'
      type: 'TEXT'
      isPK: false
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'city'
      type: 'TEXT'
      isPK: false
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'rookie_year'
      type: 'INTEGER'
      isPK: false
      fk: ''
    }
  ]

  # Events
  addTable 'Events', [
    {
      id: ++fieldIdCounter
      name: 'event_key'
      type: 'TEXT'
      isPK: true
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'event_name'
      type: 'TEXT'
      isPK: false
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'year'
      type: 'INTEGER'
      isPK: false
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'week'
      type: 'INTEGER'
      isPK: false
      fk: ''
    }
  ]

  # Matches
  addTable 'Matches', [
    {
      id: ++fieldIdCounter
      name: 'event_key'
      type: 'TEXT'
      isPK: true
      fk: 'Events.event_key'
    }
    {
      id: ++fieldIdCounter
      name: 'match_number'
      type: 'INTEGER'
      isPK: true
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'red_score'
      type: 'INTEGER'
      isPK: false
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'blue_score'
      type: 'INTEGER'
      isPK: false
      fk: ''
    }
  ]

  # ScoutReports
  addTable 'ScoutReports', [
    {
      id: ++fieldIdCounter
      name: 'event_key'
      type: 'TEXT'
      isPK: true
      fk: 'Events.event_key'
    }
    {
      id: ++fieldIdCounter
      name: 'match_number'
      type: 'INTEGER'
      isPK: true
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'team_number'
      type: 'INTEGER'
      isPK: true
      fk: 'Teams.team_number'
    }
    {
      id: ++fieldIdCounter
      name: 'auto_cycles'
      type: 'INTEGER'
      isPK: false
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'tele_cycles'
      type: 'INTEGER'
      isPK: false
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'climbed'
      type: 'BOOLEAN'
      isPK: false
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'scout_id'
      type: 'TEXT'
      isPK: false
      fk: ''
    }
    {
      id: ++fieldIdCounter
      name: 'notes'
      type: 'TEXT'
      isPK: false
      fk: ''
    }
  ]

  setActive tables[tables.length - 1].id
  render()
  return

clearAll = (silent) ->
  tables = []
  activeTab = null
  tableIdCounter = 0
  fieldIdCounter = 0
  if not silent
    render()
  return

# ── Sidebar / dark mode (same as template) ─────────────────
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
  return

toggleDark = ->
  applyTheme if html.getAttribute('data-theme') is 'dark' then 'light' else 'dark'
  return

do ->
  saved = localStorage.getItem 'frc-theme'
  prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  applyTheme saved or (if prefersDark then 'dark' else 'light')
  return

# ── Reading progress ───────────────────────────────────────
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

# ── Init ───────────────────────────────────────────────────
loadSeed()
