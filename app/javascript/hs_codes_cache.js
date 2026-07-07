const DEFAULT_CATALOG_URL = "/api/v1/reference_data/hs_codes"
const SESSION_KEY = "fbr_hs_codes_catalog_v1"

let catalogData = null
let catalogPromise = null

function readSessionCatalog() {
  try {
    const raw = sessionStorage.getItem(SESSION_KEY)
    if (!raw) return null
    const parsed = JSON.parse(raw)
    return Array.isArray(parsed) && parsed.length > 0 ? parsed : null
  } catch (_) {
    return null
  }
}

function writeSessionCatalog(data) {
  try {
    sessionStorage.setItem(SESSION_KEY, JSON.stringify(data))
  } catch (_) {
    // sessionStorage may be full or unavailable
  }
}

export function loadHsCodesCatalog(catalogUrl = DEFAULT_CATALOG_URL) {
  if (catalogData?.length) return Promise.resolve(catalogData)

  const sessionCatalog = readSessionCatalog()
  if (sessionCatalog) {
    catalogData = sessionCatalog
    return Promise.resolve(catalogData)
  }

  if (catalogPromise) return catalogPromise

  catalogPromise = fetch(catalogUrl, {
    headers: {
      Accept: "application/json",
      "X-Requested-With": "XMLHttpRequest"
    },
    credentials: "same-origin"
  })
    .then((response) => {
      if (!response.ok) throw new Error("catalog fetch failed")
      return response.json()
    })
    .then((data) => {
      catalogData = Array.isArray(data) ? data : []
      if (catalogData.length > 0) writeSessionCatalog(catalogData)
      return catalogData
    })
    .catch(() => {
      catalogPromise = null
      return null
    })

  return catalogPromise
}

export function getHsCodesCatalog() {
  return catalogData
}

export function searchHsCodes(catalog, query, limit = 50) {
  const q = query.trim().toLowerCase()
  if (q.length < 2 || !Array.isArray(catalog)) return []

  const results = []
  for (const item of catalog) {
    const code = (item.code || item.hS_CODE || item.HS_CODE || "").toLowerCase()
    const desc = (item.description || item.DESCRIPTION || "").toLowerCase()
    if (code.includes(q) || desc.includes(q)) {
      results.push(item)
      if (results.length >= limit) break
    }
  }
  return results
}
