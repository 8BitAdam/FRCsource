# Function to open the sidebar
openSidebar = ->
  document.getElementById('mySidebar').classList.add 'open'
  document.getElementById('myOverlay').style.display = 'block'
  document.body.style.overflow = 'hidden'

# Function to close the sidebar
closeSidebar = ->
  document.getElementById('mySidebar').classList.remove 'open'
  document.getElementById('myOverlay').style.display = 'none'
  document.body.style.overflow = ''

# Theme state variables
html = document.documentElement
darkLabel = document.getElementById 'darkLabel'

# Function to apply a specific theme
applyTheme = (theme) ->
  html.setAttribute 'data-theme', theme
  localStorage.setItem 'frc-theme', theme
  if darkLabel
    darkLabel.textContent = if theme is 'dark' then 'Light' else 'Dark'

# Function to toggle between light and dark themes
toggleDark = ->
  applyTheme (if html.getAttribute('data-theme') is 'dark' then 'light' else 'dark')

# Initialization IIFE for theme persistence
do ->
  saved = localStorage.getItem 'frc-theme'
  prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches
  applyTheme (saved or (if prefersDark then 'dark' else 'light'))

# Progress and TOC tracking variables
progressFill = document.getElementById 'readingProgress'
sections = document.querySelectorAll '.article-body h2[id]'
tocItems = document.querySelectorAll '.toc-list li[id]'

# Function to update reading progress and TOC highlight
updateProgress = ->
  scrollTop = window.scrollY
  docHeight = document.documentElement.scrollHeight - window.innerHeight
  progress = if docHeight > 0 then Math.round((scrollTop / docHeight) * 100) else 0
  
  if progressFill
    progressFill.style.width = "#{progress}%"

  activeId = null
  sections.forEach (sec) ->
    if scrollTop >= sec.offsetTop - 120
      activeId = sec.id

  tocItems.forEach (item) ->
    item.classList.remove 'active'
    if item.id is "toc-#{activeId}"
      item.classList.add 'active'

# Event listeners and initial execution
window.addEventListener 'scroll', updateProgress, { passive: true }
updateProgress()

# To ensure functions are globally accessible (e.g., for onclick attributes)
# we explicitly export them to the window object.
window.openSidebar = openSidebar
window.closeSidebar = closeSidebar
window.toggleDark = toggleDark
