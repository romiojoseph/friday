const API_BASE = "";

async function jsonFetch(path, init) {
  const res = await fetch(`${API_BASE}${path}`, init);
  const data = await res.json();
  return { res, data };
}

export async function fetchProjects() {
  const res = await fetch(`${API_BASE}/api/projects`, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed to fetch projects");
  return res.json();
}

export async function fetchSettings() {
  const res = await fetch(`${API_BASE}/api/settings`, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed to fetch settings");
  return res.json();
}

export async function saveSettings(payload) {
  const { data } = await jsonFetch("/api/settings", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return data;
}

export async function fetchBackups(index) {
  const res = await fetch(`${API_BASE}/api/backups?index=${index}`, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed to fetch backups");
  return res.json();
}

export async function fetchPreview(index) {
  const res = await fetch(`${API_BASE}/api/preview?index=${index}`, { cache: "no-store" });
  if (!res.ok) throw new Error("Failed to fetch preview");
  return res.json();
}

export async function browseFolder() {
  const res = await fetch(`${API_BASE}/api/browse`);
  if (!res.ok) throw new Error("Failed to browse");
  return res.text();
}

export async function browseFile() {
  const res = await fetch(`${API_BASE}/api/browse_file`);
  if (!res.ok) throw new Error("Failed to browse");
  return res.text();
}

export async function addProject(payload) {
  const { data } = await jsonFetch("/api/add", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return data;
}

export async function editProject(payload) {
  const { data } = await jsonFetch("/api/edit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return data;
}

export async function removeProject(index) {
  const { data } = await jsonFetch("/api/remove", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ index }),
  });
  return data;
}

export async function triggerBackup(index, note) {
  const { data } = await jsonFetch("/api/backup", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ index, note }),
  });
  return data;
}

export async function triggerCleanup(index, limit) {
  const { data } = await jsonFetch("/api/cleanup", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ index, limit }),
  });
  return data;
}

export async function triggerRestore(index, filename) {
  const body = filename ? { index, filename } : { index };
  const { data } = await jsonFetch("/api/restore", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return data;
}

export async function deleteBackups(index, filenames) {
  const { data } = await jsonFetch("/api/delete_backups", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ index, filenames }),
  });
  return data;
}

export async function openDestination(index) {
  const { data } = await jsonFetch("/api/open_destination", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ index }),
  });
  return data;
}

export async function openSource(index) {
  const { data } = await jsonFetch("/api/open_source", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ index }),
  });
  return data;
}

export async function revealBackup(index, filename) {
  const { data } = await jsonFetch("/api/reveal_backup", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ index, filename }),
  });
  return data;
}
