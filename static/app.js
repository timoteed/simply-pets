/**
 * SimplyPets — Modern Pet & Medication Tracker
 * Vanilla ES6 JavaScript Frontend Architecture
 */

(function () {
  'use strict';

  // --- STATE ---
  const state = {
    user: null,
    pets: [],
    selectedPet: null,
    todayMeds: [],
    stats: { total_pets: 0, active_medications: 0, meds_taken_today: 0 },
    activeTab: 'pets', // 'pets' | 'schedule'
    detailTab: 'meds', // 'meds' | 'weight' | 'care'
    searchQuery: '',
    speciesFilter: 'all',
    sortBy: 'name_asc',
    selectedAvatar: 'dog',
    pendingDeletePet: null
  };

  // Avatar emoji map
  const AVATAR_MAP = {
    dog: '🐶',
    cat: '🐱',
    rabbit: '🐰',
    bird: '🦜',
    hamster: '🐹',
    paw: '🐾',
    reptile: '🦎',
    fish: '🐠'
  };

  // --- DOM ELEMENTS ---
  const elements = {
    // Navigation & Stats
    statTotalPets: document.getElementById('statTotalPets'),
    statActiveMeds: document.getElementById('statActiveMeds'),
    statDosesToday: document.getElementById('statDosesToday'),
    tabPetsBtn: document.getElementById('tabPetsBtn'),
    tabScheduleBtn: document.getElementById('tabScheduleBtn'),
    tabPetsCount: document.getElementById('tabPetsCount'),
    tabScheduleCount: document.getElementById('tabScheduleCount'),
    petsViewSection: document.getElementById('petsViewSection'),
    scheduleViewSection: document.getElementById('scheduleViewSection'),
    currentDateBadge: document.getElementById('currentDateBadge'),

    // Search & Filter
    searchInput: document.getElementById('searchInput'),
    speciesFilter: document.getElementById('speciesFilter'),
    sortFilter: document.getElementById('sortFilter'),
    petsGrid: document.getElementById('petsGrid'),
    emptyPetsState: document.getElementById('emptyPetsState'),
    todayScheduleGrid: document.getElementById('todayScheduleGrid'),
    emptyScheduleState: document.getElementById('emptyScheduleState'),

    // Theme & Header actions
    themeToggleBtn: document.getElementById('themeToggleBtn'),
    loadDemoBtn: document.getElementById('loadDemoBtn'),
    exportModalBtn: document.getElementById('exportModalBtn'),
    openAddPetModalBtn: document.getElementById('openAddPetModalBtn'),
    emptyAddPetBtn: document.getElementById('emptyAddPetBtn'),
    emptySampleBtn: document.getElementById('emptySampleBtn'),

    // Modals
    petModal: document.getElementById('petModal'),
    petModalTitle: document.getElementById('petModalTitle'),
    petForm: document.getElementById('petForm'),
    petFormId: document.getElementById('petFormId'),
    petFormName: document.getElementById('petFormName'),
    petFormSpecies: document.getElementById('petFormSpecies'),
    petFormBreed: document.getElementById('petFormBreed'),
    petFormWeight: document.getElementById('petFormWeight'),
    petFormWeightUnit: document.getElementById('petFormWeightUnit'),
    petFormBirthdate: document.getElementById('petFormBirthdate'),
    petFormGender: document.getElementById('petFormGender'),
    petFormMicrochip: document.getElementById('petFormMicrochip'),
    petFormVet: document.getElementById('petFormVet'),
    petFormNotes: document.getElementById('petFormNotes'),
    avatarPicker: document.getElementById('avatarPicker'),
    initialMedSection: document.getElementById('initialMedSection'),
    initMedName: document.getElementById('initMedName'),
    initMedDosage: document.getElementById('initMedDosage'),
    initMedFreq: document.getElementById('initMedFreq'),
    initMedInstructions: document.getElementById('initMedInstructions'),

    // Detail Modal
    detailModal: document.getElementById('detailModal'),
    detailModalBody: document.getElementById('detailModalBody'),
    detailHeaderTitle: document.getElementById('detailHeaderTitle'),
    printPetBtn: document.getElementById('printPetBtn'),

    // Medication Modal
    medicationModal: document.getElementById('medicationModal'),
    medModalTitle: document.getElementById('medModalTitle'),
    medicationForm: document.getElementById('medicationForm'),
    medFormPetId: document.getElementById('medFormPetId'),
    medFormId: document.getElementById('medFormId'),
    medFormName: document.getElementById('medFormName'),
    medFormDosage: document.getElementById('medFormDosage'),
    medFormFrequency: document.getElementById('medFormFrequency'),
    medFormTimeOfDay: document.getElementById('medFormTimeOfDay'),
    medFormStartDate: document.getElementById('medFormStartDate'),
    medFormEndDate: document.getElementById('medFormEndDate'),
    medFormPrescribingVet: document.getElementById('medFormPrescribingVet'),
    medFormInstructions: document.getElementById('medFormInstructions'),
    medFormIsActive: document.getElementById('medFormIsActive'),

    // Weight Modal
    weightModal: document.getElementById('weightModal'),
    weightForm: document.getElementById('weightForm'),
    weightFormPetId: document.getElementById('weightFormPetId'),
    weightFormVal: document.getElementById('weightFormVal'),
    weightFormUnit: document.getElementById('weightFormUnit'),
    weightFormDate: document.getElementById('weightFormDate'),
    weightFormNotes: document.getElementById('weightFormNotes'),

    // Export Modal
    exportModal: document.getElementById('exportModal'),
    downloadJsonBtn: document.getElementById('downloadJsonBtn'),
    copyJsonBtn: document.getElementById('copyJsonBtn'),
    triggerImportFileBtn: document.getElementById('triggerImportFileBtn'),
    importFileInput: document.getElementById('importFileInput'),
    clearAllDataBtn: document.getElementById('clearAllDataBtn'),

    // Delete Pet Confirmation Modal
    petFormDeleteBtn: document.getElementById('petFormDeleteBtn'),
    deleteConfirmModal: document.getElementById('deleteConfirmModal'),
    deleteTargetPetName: document.getElementById('deleteTargetPetName'),
    confirmDeletePetBtn: document.getElementById('confirmDeletePetBtn'),

    // Auth & User
    currentUserChip: document.getElementById('currentUserChip'),
    logoutBtn: document.getElementById('logoutBtn'),

    // Toasts
    toastContainer: document.getElementById('toastContainer')
  };

  // --- AUTH SESSION ---
  const TOKEN_KEY = 'simplypets-token';
  const USER_KEY = 'simplypets-user';

  function getToken() {
    try {
      return localStorage.getItem(TOKEN_KEY);
    } catch (e) {
      return null;
    }
  }

  function clearSession() {
    try {
      localStorage.removeItem(TOKEN_KEY);
      localStorage.removeItem(USER_KEY);
    } catch (e) {}
  }

  function redirectToLogin() {
    window.location.replace('/login.html');
  }

  function renderUserChip() {
    if (!elements.currentUserChip) return;
    const label = state.user ? (state.user.display_name || state.user.username) : '';
    elements.currentUserChip.textContent = label;
    if (label) {
      elements.currentUserChip.title = `Logged in as ${state.user.username}`;
    }
  }

  async function handleLogout() {
    const token = getToken();
    try {
      if (token) {
        await fetch('/api/auth/logout', {
          method: 'POST',
          headers: { 'Authorization': 'Bearer ' + token }
        });
      }
    } catch (err) {
      console.error('Logout request failed:', err);
    }
    clearSession();
    redirectToLogin();
  }

  // --- API CLIENT ---
  async function apiRequest(endpoint, options = {}) {
    try {
      const headers = { 'Content-Type': 'application/json', ...(options.headers || {}) };
      const token = getToken();
      if (token) {
        headers['Authorization'] = 'Bearer ' + token;
      }
      const res = await fetch(endpoint, { ...options, headers });
      const data = await res.json();
      if (res.status === 401) {
        clearSession();
        redirectToLogin();
        throw new Error('Session expired. Please log in again.');
      }
      if (!res.ok) {
        throw new Error(data.error || 'Server error');
      }
      return data;
    } catch (err) {
      showToast(err.message, 'error');
      throw err;
    }
  }

  // --- INITIALIZATION ---
  async function init() {
    initTheme();
    initDateBadge();
    const authenticated = await verifySession();
    if (!authenticated) return;
    bindEvents();
    await loadInitialData();
  }

  async function verifySession() {
    const token = getToken();
    if (!token) {
      redirectToLogin();
      return false;
    }
    try {
      const res = await fetch('/api/auth/me', {
        headers: { 'Authorization': 'Bearer ' + token }
      });
      if (!res.ok) {
        clearSession();
        redirectToLogin();
        return false;
      }
      state.user = await res.json();
      try {
        localStorage.setItem(USER_KEY, JSON.stringify(state.user));
      } catch (e) {}
      renderUserChip();
      return true;
    } catch (err) {
      console.error('Session check failed:', err);
      showToast('Could not reach the server. Please check your connection.', 'error');
      return false;
    }
  }

  function initDateBadge() {
    const today = new Date();
    const options = { weekday: 'short', month: 'short', day: 'numeric', year: 'numeric' };
    if (elements.currentDateBadge) {
      elements.currentDateBadge.textContent = '📅 ' + today.toLocaleDateString(undefined, options);
    }
  }

  async function loadInitialData() {
    try {
      await Promise.all([refreshPets(), refreshStats(), refreshTodayMeds()]);
    } catch (err) {
      console.error('Initial load failed:', err);
    }
  }

  async function refreshPets() {
    const data = await apiRequest('/api/pets');
    state.pets = data || [];
    renderPetsGrid();
    updateNavigationBadges();
  }

  async function refreshStats() {
    const stats = await apiRequest('/api/stats');
    state.stats = stats || { total_pets: 0, active_medications: 0, meds_taken_today: 0 };
    elements.statTotalPets.textContent = state.stats.total_pets;
    elements.statActiveMeds.textContent = state.stats.active_medications;
    elements.statDosesToday.textContent = state.stats.meds_taken_today;
  }

  async function refreshTodayMeds() {
    const meds = await apiRequest('/api/medications/today');
    state.todayMeds = meds || [];
    renderTodaySchedule();
    updateNavigationBadges();
  }

  function updateNavigationBadges() {
    elements.tabPetsCount.textContent = state.pets.length;
    elements.tabScheduleCount.textContent = state.todayMeds.length;
  }

  // --- THEME MANAGEMENT ---
  function initTheme() {
    const saved = localStorage.getItem('simplypets-theme');
    const prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    const theme = saved || (prefersDark ? 'dark' : 'light');
    setTheme(theme);
  }

  function setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('simplypets-theme', theme);
    elements.themeToggleBtn.setAttribute('title', `Switch to ${theme === 'dark' ? 'Light' : 'Dark'} Mode`);
  }

  function toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme') || 'light';
    setTheme(current === 'dark' ? 'light' : 'dark');
  }

  // --- TOAST NOTIFICATIONS ---
  function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    const icon = type === 'success' ? '✅' : type === 'error' ? '⚠️' : 'ℹ️';
    toast.innerHTML = `<span>${icon}</span><span>${escapeHtml(message)}</span>`;
    elements.toastContainer.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateX(20px)';
      toast.style.transition = 'all 0.3s ease';
      setTimeout(() => toast.remove(), 300);
    }, 3200);
  }

  // --- RENDERING PETS GRID ---
  function renderPetsGrid() {
    const filtered = filterAndSortPets(state.pets);

    if (filtered.length === 0) {
      elements.petsGrid.innerHTML = '';
      elements.emptyPetsState.style.display = 'flex';
      return;
    }

    elements.emptyPetsState.style.display = 'none';

    elements.petsGrid.innerHTML = filtered.map(pet => {
      const avatarEmoji = AVATAR_MAP[pet.avatar] || '🐾';
      const weightDisplay = `${pet.weight} ${pet.weight_unit}`;
      const activeMedCount = pet.active_med_count || 0;
      const totalMedCount = pet.total_med_count || 0;

      const medBadge = activeMedCount > 0
        ? `<span class="metric-pill" style="border-color: var(--accent-amber); background: var(--accent-amber-light); color: var(--accent-amber-text);">
            💊 <strong>${activeMedCount}</strong> active med${activeMedCount > 1 ? 's' : ''}
          </span>`
        : `<span class="metric-pill" style="color: var(--text-muted);">
            No active meds
          </span>`;

      return `
        <article class="pet-card" data-pet-id="${pet.id}">
          <div class="pet-card-header">
            <div class="pet-avatar">${avatarEmoji}</div>
            <div class="pet-header-info">
              <div class="pet-name-row">
                <h3 class="pet-name">${escapeHtml(pet.name)}</h3>
                <span class="species-pill ${escapeHtml(pet.species)}">${escapeHtml(pet.species)}</span>
              </div>
              <p class="pet-breed">${escapeHtml(pet.breed || 'Unknown breed')}</p>
            </div>
          </div>

          <div class="pet-card-body">
            <div class="metric-pill-row">
              <div class="metric-pill">
                <span class="metric-label">Weight:</span>
                <span class="metric-val">${weightDisplay}</span>
              </div>
              ${pet.gender && pet.gender !== 'Unknown' ? `
                <div class="metric-pill">
                  <span class="metric-label">${escapeHtml(pet.gender)}</span>
                </div>
              ` : ''}
            </div>

            <div class="metric-pill-row">
              ${medBadge}
            </div>

            ${pet.notes ? `
              <p style="font-size: 0.825rem; color: var(--text-muted); line-height: 1.4; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;">
                ${escapeHtml(pet.notes)}
              </p>
            ` : ''}
          </div>

          <div class="pet-card-footer">
            <span style="color: var(--text-muted); font-size: 0.8rem;">Click to view health record</span>
            <div class="actions" onclick="event.stopPropagation()">
              <button class="btn btn-secondary btn-sm edit-pet-btn" data-pet-id="${pet.id}" title="Edit pet info">
                ✏️ Edit
              </button>
            </div>
          </div>
        </article>
      `;
    }).join('');

    // Attach card click handlers
    elements.petsGrid.querySelectorAll('.pet-card').forEach(card => {
      card.addEventListener('click', () => {
        const id = card.getAttribute('data-pet-id');
        openPetDetailModal(id);
      });
    });

    elements.petsGrid.querySelectorAll('.edit-pet-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const id = btn.getAttribute('data-pet-id');
        openEditPetModal(id);
      });
    });
  }

  function filterAndSortPets(list) {
    let result = [...list];

    // Search query filter (name, breed)
    if (state.searchQuery) {
      const q = state.searchQuery.toLowerCase();
      result = result.filter(p =>
        (p.name && p.name.toLowerCase().includes(q)) ||
        (p.breed && p.breed.toLowerCase().includes(q)) ||
        (p.species && p.species.toLowerCase().includes(q))
      );
    }

    // Species filter
    if (state.speciesFilter !== 'all') {
      result = result.filter(p => p.species === state.speciesFilter);
    }

    // Sorting
    switch (state.sortBy) {
      case 'name_asc':
        result.sort((a, b) => a.name.localeCompare(b.name));
        break;
      case 'name_desc':
        result.sort((a, b) => b.name.localeCompare(a.name));
        break;
      case 'weight_desc':
        result.sort((a, b) => (b.weight || 0) - (a.weight || 0));
        break;
      case 'weight_asc':
        result.sort((a, b) => (a.weight || 0) - (b.weight || 0));
        break;
      case 'meds_desc':
        result.sort((a, b) => (b.active_med_count || 0) - (a.active_med_count || 0));
        break;
      default:
        result.sort((a, b) => a.name.localeCompare(b.name));
    }

    return result;
  }

  // --- RENDERING TODAY'S MEDICATION SCHEDULE ---
  function renderTodaySchedule() {
    if (state.todayMeds.length === 0) {
      elements.todayScheduleGrid.innerHTML = '';
      elements.emptyScheduleState.style.display = 'flex';
      return;
    }

    elements.emptyScheduleState.style.display = 'none';

    elements.todayScheduleGrid.innerHTML = state.todayMeds.map(med => {
      const avatarEmoji = AVATAR_MAP[med.pet_avatar] || '🐾';
      const isTaken = (med.doses_given_today || 0) > 0;

      return `
        <div class="schedule-item ${isTaken ? 'taken' : ''}">
          <div class="schedule-pet-info">
            <div class="schedule-avatar">${avatarEmoji}</div>
            <div class="schedule-med-details">
              <div class="name">${escapeHtml(med.name)}</div>
              <div class="dose">${escapeHtml(med.dosage)} • <span style="color: var(--text-main);">${escapeHtml(med.pet_name)}</span></div>
            </div>
          </div>

          <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
            <span class="med-meta-tag">⏰ ${escapeHtml(med.frequency)}</span>
            <span class="med-meta-tag">☀️ ${escapeHtml(med.time_of_day || 'Morning')}</span>
          </div>

          ${med.instructions ? `
            <div class="schedule-instructions">
              📝 ${escapeHtml(med.instructions)}
            </div>
          ` : ''}

          <div class="schedule-action-row">
            <span style="font-size: 0.8rem; font-weight: 600; color: ${isTaken ? 'var(--accent-green-text)' : 'var(--text-muted)'};">
              ${isTaken ? `✓ Dose given today (${med.doses_given_today}x)` : 'Pending dose'}
            </span>

            <button class="take-dose-btn ${isTaken ? 'given' : ''}" data-med-id="${med.id}">
              ${isTaken ? '✓ Taken' : 'Mark Taken'}
            </button>
          </div>
        </div>
      `;
    }).join('');

    elements.todayScheduleGrid.querySelectorAll('.take-dose-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const medId = btn.getAttribute('data-med-id');
        await recordDose(medId);
      });
    });
  }

  async function recordDose(medId) {
    try {
      await apiRequest(`/api/medications/${medId}/dose`, {
        method: 'POST',
        body: JSON.stringify({ notes: 'Logged via daily tracker' })
      });
      showToast('Dose recorded successfully! 🐾');
      await refreshTodayMeds();
      await refreshStats();
      if (state.selectedPet) {
        await refreshSelectedPetDetail();
      }
    } catch (err) {
      console.error(err);
    }
  }

  // --- PET DETAIL & HEALTH RECORD MODAL ---
  async function openPetDetailModal(petId) {
    try {
      const pet = await apiRequest(`/api/pets/${petId}`);
      state.selectedPet = pet;
      renderPetDetailContent(pet);
      openModal(elements.detailModal);
    } catch (err) {
      console.error(err);
    }
  }

  async function refreshSelectedPetDetail() {
    if (!state.selectedPet) return;
    const pet = await apiRequest(`/api/pets/${state.selectedPet.id}`);
    state.selectedPet = pet;
    renderPetDetailContent(pet);
  }

  function renderPetDetailContent(pet) {
    const avatarEmoji = AVATAR_MAP[pet.avatar] || '🐾';
    const meds = pet.medications || [];
    const weights = pet.weight_history || [];

    // Calculate weight trend
    let weightTrendHtml = '';
    if (weights.length > 1) {
      const latest = weights[weights.length - 1].weight;
      const prev = weights[weights.length - 2].weight;
      const diff = (latest - prev).toFixed(1);
      const diffNum = parseFloat(diff);
      if (diffNum > 0) {
        weightTrendHtml = `<span style="font-size: 0.8rem; color: var(--accent-amber-text); font-weight: 600;">(+${diff} ${pet.weight_unit} from previous)</span>`;
      } else if (diffNum < 0) {
        weightTrendHtml = `<span style="font-size: 0.8rem; color: var(--accent-blue-text); font-weight: 600;">(${diff} ${pet.weight_unit} from previous)</span>`;
      } else {
        weightTrendHtml = `<span style="font-size: 0.8rem; color: var(--text-muted); font-weight: 600;">(Stable weight)</span>`;
      }
    }

    if (elements.detailHeaderTitle) {
      elements.detailHeaderTitle.textContent = `${pet.name}'s Health Record`;
    }

    elements.detailModalBody.innerHTML = `
      <!-- Pet Bio Banner -->
      <div class="detail-banner">
        <div class="detail-bio">
          <div class="detail-avatar-large">${avatarEmoji}</div>
          <div class="detail-title">
            <h2>
              ${escapeHtml(pet.name)}
              <span class="species-pill ${escapeHtml(pet.species)}">${escapeHtml(pet.species)}</span>
            </h2>
            <div class="detail-subtitle">
              ${escapeHtml(pet.breed || 'Unknown breed')} • ${escapeHtml(pet.gender || 'Unknown gender')}
              ${pet.birthdate ? ` • Born ${escapeHtml(pet.birthdate)}` : ''}
            </div>
            <div style="margin-top: 0.5rem; display: flex; align-items: center; gap: 0.5rem;">
              <span style="font-weight: 700; font-size: 1.1rem; color: var(--primary);">${pet.weight} ${pet.weight_unit}</span>
              ${weightTrendHtml}
            </div>
          </div>
        </div>

        <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
          <button id="detailEditPetBtn" class="btn btn-secondary btn-sm">
            ✏️ Edit Info
          </button>
        </div>
      </div>

      <!-- Navigation Tabs inside Detail -->
      <div class="detail-tabs">
        <button class="detail-tab-btn ${state.detailTab === 'meds' ? 'active' : ''}" data-detail-tab="meds">
          💊 Medications (${meds.length})
        </button>
        <button class="detail-tab-btn ${state.detailTab === 'weight' ? 'active' : ''}" data-detail-tab="weight">
          📈 Weight Tracker (${weights.length})
        </button>
        <button class="detail-tab-btn ${state.detailTab === 'care' ? 'active' : ''}" data-detail-tab="care">
          🏥 Care & Vet Info
        </button>
      </div>

      <!-- TAB 1: MEDICATIONS -->
      <div id="detailMedsSection" style="display: ${state.detailTab === 'meds' ? 'flex' : 'none'}; flex-direction: column; gap: 1rem;">
        <div style="display: flex; align-items: center; justify-content: space-between; margin-top: 0.5rem;">
          <div>
            <h4 style="font-size: 1.1rem;">Medications & Prescriptions</h4>
            <p style="color: var(--text-muted); font-size: 0.85rem;">Active schedules and medication instructions</p>
          </div>
          <button id="addMedicationBtn" class="btn btn-primary btn-sm">
            + Add Medication
          </button>
        </div>

        ${meds.length === 0 ? `
          <div class="empty-state" style="padding: 2.5rem 1rem;">
            <div style="font-size: 2.5rem;">💊</div>
            <h4>No medications recorded</h4>
            <p style="font-size: 0.85rem;">Track pills, drops, vaccines, or regular supplements for ${escapeHtml(pet.name)}.</p>
            <button id="emptyAddMedBtn" class="btn btn-primary btn-sm">+ Add First Medication</button>
          </div>
        ` : `
          <div style="display: flex; flex-direction: column; gap: 0.85rem;">
            ${meds.map(med => {
              const isActive = med.is_active === 1;
              const dosesToday = med.taken_today_count || 0;
              return `
                <div class="med-card-item">
                  <div class="med-card-content">
                    <div class="med-title-row">
                      <span class="med-name-large">${escapeHtml(med.name)}</span>
                      <span class="${isActive ? 'badge-active' : 'badge-inactive'}">
                        ${isActive ? 'Active' : 'Inactive / Completed'}
                      </span>
                    </div>

                    <div class="med-meta-pills">
                      <span class="med-meta-tag">💊 Dosage: <strong>${escapeHtml(med.dosage)}</strong></span>
                      <span class="med-meta-tag">⏰ Frequency: <strong>${escapeHtml(med.frequency)}</strong></span>
                      <span class="med-meta-tag">☀️ Time: <strong>${escapeHtml(med.time_of_day || 'Anytime')}</strong></span>
                      ${med.start_date ? `<span class="med-meta-tag">📅 Started: ${escapeHtml(med.start_date)}</span>` : ''}
                      ${med.prescribing_vet ? `<span class="med-meta-tag">🩺 Vet: ${escapeHtml(med.prescribing_vet)}</span>` : ''}
                    </div>

                    ${med.instructions ? `
                      <p class="med-instructions-text">
                        <strong>Instructions:</strong> ${escapeHtml(med.instructions)}
                      </p>
                    ` : ''}

                    <div style="margin-top: 0.75rem; display: flex; align-items: center; gap: 0.75rem; flex-wrap: wrap;">
                      <button class="btn btn-secondary btn-sm log-dose-btn" data-med-id="${med.id}">
                        ${dosesToday > 0 ? `✓ Dose Logged Today (${dosesToday}x)` : 'Mark Dose Given Today'}
                      </button>
                      <button class="btn btn-secondary btn-sm edit-med-btn" data-med-id="${med.id}">
                        ✏️ Edit
                      </button>
                      <button class="btn btn-secondary btn-sm delete-med-btn" data-med-id="${med.id}" style="color: var(--accent-red);">
                        🗑️ Delete
                      </button>
                    </div>
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        `}
      </div>

      <!-- TAB 2: WEIGHT TRACKER -->
      <div id="detailWeightSection" style="display: ${state.detailTab === 'weight' ? 'flex' : 'none'}; flex-direction: column; gap: 1rem;">
        <div style="display: flex; align-items: center; justify-content: space-between; margin-top: 0.5rem;">
          <div>
            <h4 style="font-size: 1.1rem;">Weight Trend History</h4>
            <p style="color: var(--text-muted); font-size: 0.85rem;">Keep tabs on healthy growth and diet management</p>
          </div>
          <button id="addWeightLogBtn" class="btn btn-primary btn-sm">
            + Record Weight
          </button>
        </div>

        <div class="weight-chart-wrapper">
          <div class="chart-header">
            <span style="font-weight: 600; font-size: 0.9rem;">Weight Progression Chart</span>
            <span style="font-size: 0.825rem; color: var(--text-muted);">Current: ${pet.weight} ${pet.weight_unit}</span>
          </div>
          <div id="weightChartContainer" class="weight-svg-container">
            ${renderWeightChartSvg(weights, pet.weight_unit)}
          </div>
        </div>

        <div>
          <h5 style="margin-bottom: 0.5rem; font-size: 0.95rem;">Recorded Weigh-ins</h5>
          ${weights.length === 0 ? `
            <p style="color: var(--text-muted); font-size: 0.85rem;">No weight logs recorded yet.</p>
          ` : `
            <table class="weight-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Weight</th>
                  <th>Notes</th>
                  <th style="width: 50px;"></th>
                </tr>
              </thead>
              <tbody>
                ${[...weights].reverse().map(w => `
                  <tr>
                    <td><strong>${escapeHtml(w.logged_date)}</strong></td>
                    <td>${w.weight} ${escapeHtml(w.weight_unit)}</td>
                    <td style="color: var(--text-muted);">${escapeHtml(w.notes || '—')}</td>
                    <td>
                      <button class="delete-weight-btn" data-weight-id="${w.id}" style="color: var(--accent-red); cursor: pointer;" title="Delete log">
                        &times;
                      </button>
                    </td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          `}
        </div>
      </div>

      <!-- TAB 3: CARE & VET INFO -->
      <div id="detailCareSection" style="display: ${state.detailTab === 'care' ? 'flex' : 'none'}; flex-direction: column; gap: 1rem;">
        <div style="background: var(--bg-surface-hover); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 1.25rem;">
          <h4 style="margin-bottom: 0.75rem; font-size: 1rem;">Veterinarian & Clinic</h4>
          <p style="font-size: 0.95rem; font-weight: 500;">
            ${pet.vet_info ? escapeHtml(pet.vet_info) : '<span style="color: var(--text-muted);">No vet information recorded. Edit pet to add clinic contact.</span>'}
          </p>
        </div>

        <div style="background: var(--bg-surface-hover); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 1.25rem;">
          <h4 style="margin-bottom: 0.75rem; font-size: 1rem;">Microchip Identification</h4>
          <p style="font-size: 0.95rem; font-weight: 500; font-family: monospace;">
            ${pet.microchip_id ? escapeHtml(pet.microchip_id) : '<span style="color: var(--text-muted); font-family: inherit;">No microchip ID recorded.</span>'}
          </p>
        </div>

        <div style="background: var(--bg-surface-hover); border: 1px solid var(--border-color); border-radius: var(--radius-md); padding: 1.25rem;">
          <h4 style="margin-bottom: 0.75rem; font-size: 1rem;">Allergies, Dietary & Special Care Notes</h4>
          <p style="font-size: 0.95rem; line-height: 1.5;">
            ${pet.notes ? escapeHtml(pet.notes) : '<span style="color: var(--text-muted);">No special care notes recorded.</span>'}
          </p>
        </div>
      </div>
    `;

    // Bind Detail Tab Buttons
    elements.detailModalBody.querySelectorAll('.detail-tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        state.detailTab = btn.getAttribute('data-detail-tab');
        renderPetDetailContent(state.selectedPet);
      });
    });

    // Detail Action Buttons
    const editBtn = elements.detailModalBody.querySelector('#detailEditPetBtn');
    if (editBtn) editBtn.addEventListener('click', () => openEditPetModal(pet.id));

    // Medication Action Buttons
    const addMedBtn = elements.detailModalBody.querySelector('#addMedicationBtn');
    if (addMedBtn) addMedBtn.addEventListener('click', () => openAddMedicationModal(pet.id));

    const emptyAddMedBtn = elements.detailModalBody.querySelector('#emptyAddMedBtn');
    if (emptyAddMedBtn) emptyAddMedBtn.addEventListener('click', () => openAddMedicationModal(pet.id));

    elements.detailModalBody.querySelectorAll('.log-dose-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const medId = btn.getAttribute('data-med-id');
        await recordDose(medId);
      });
    });

    elements.detailModalBody.querySelectorAll('.edit-med-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const medId = btn.getAttribute('data-med-id');
        const med = (pet.medications || []).find(m => m.id == medId);
        if (med) openEditMedicationModal(pet.id, med);
      });
    });

    elements.detailModalBody.querySelectorAll('.delete-med-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const medId = btn.getAttribute('data-med-id');
        if (confirm('Are you sure you want to remove this medication?')) {
          await apiRequest(`/api/medications/${medId}`, { method: 'DELETE' });
          showToast('Medication removed');
          await refreshSelectedPetDetail();
          await refreshPets();
          await refreshTodayMeds();
          await refreshStats();
        }
      });
    });

    // Weight Action Buttons
    const addWeightBtn = elements.detailModalBody.querySelector('#addWeightLogBtn');
    if (addWeightBtn) addWeightBtn.addEventListener('click', () => openAddWeightModal(pet.id, pet.weight_unit));

    elements.detailModalBody.querySelectorAll('.delete-weight-btn').forEach(btn => {
      btn.addEventListener('click', async () => {
        const logId = btn.getAttribute('data-weight-id');
        if (confirm('Delete this weight entry?')) {
          await apiRequest(`/api/weights/${logId}`, { method: 'DELETE' });
          showToast('Weight entry deleted');
          await refreshSelectedPetDetail();
          await refreshPets();
        }
      });
    });
  }

  // --- SVG WEIGHT CHART BUILDER ---
  function renderWeightChartSvg(weights, unit) {
    if (!weights || weights.length === 0) {
      return `
        <div style="height: 100%; display: flex; align-items: center; justify-content: center; color: var(--text-muted); font-size: 0.875rem;">
          No weight history entries yet. Add entries to view trend.
        </div>
      `;
    }

    const width = 760;
    const height = 220;
    const padX = 50;
    const padY = 30;

    const values = weights.map(w => w.weight);
    let minVal = Math.min(...values);
    let maxVal = Math.max(...values);

    // Padding min and max
    if (minVal === maxVal) {
      minVal = Math.max(0, minVal - 2);
      maxVal = maxVal + 2;
    } else {
      const margin = (maxVal - minVal) * 0.15;
      minVal = Math.max(0, minVal - margin);
      maxVal = maxVal + margin;
    }

    const points = weights.map((w, i) => {
      const x = weights.length === 1
        ? width / 2
        : padX + (i / (weights.length - 1)) * (width - 2 * padX);
      const y = height - padY - ((w.weight - minVal) / (maxVal - minVal)) * (height - 2 * padY);
      return { x, y, weight: w.weight, date: w.logged_date };
    });

    let pathD = '';
    if (points.length === 1) {
      pathD = `M ${points[0].x - 10} ${points[0].y} L ${points[0].x + 10} ${points[0].y}`;
    } else {
      pathD = points.reduce((acc, pt, idx) => {
        return idx === 0 ? `M ${pt.x} ${pt.y}` : `${acc} L ${pt.x} ${pt.y}`;
      }, '');
    }

    const areaD = points.length > 1
      ? `${pathD} L ${points[points.length - 1].x} ${height - padY} L ${points[0].x} ${height - padY} Z`
      : '';

    return `
      <svg viewBox="0 0 ${width} ${height}" style="width: 100%; height: 100%; overflow: visible;">
        <defs>
          <linearGradient id="chartGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stop-color="#0D9488" stop-opacity="0.28"/>
            <stop offset="100%" stop-color="#0D9488" stop-opacity="0.0"/>
          </linearGradient>
        </defs>

        <!-- Grid lines & Y-axis guides -->
        <line x1="${padX}" y1="${padY}" x2="${width - padX}" y2="${padY}" stroke="var(--border-color)" stroke-dasharray="3 3"/>
        <text x="${padX - 8}" y="${padY + 4}" fill="var(--text-muted)" font-size="11" text-anchor="end">${maxVal.toFixed(1)} ${unit}</text>

        <line x1="${padX}" y1="${height / 2}" x2="${width - padX}" y2="${height / 2}" stroke="var(--border-color)" stroke-dasharray="3 3"/>

        <line x1="${padX}" y1="${height - padY}" x2="${width - padX}" y2="${height - padY}" stroke="var(--border-color)"/>
        <text x="${padX - 8}" y="${height - padY + 4}" fill="var(--text-muted)" font-size="11" text-anchor="end">${minVal.toFixed(1)} ${unit}</text>

        <!-- Gradient fill under line -->
        ${areaD ? `<path d="${areaD}" fill="url(#chartGradient)"/>` : ''}

        <!-- Line path -->
        <path d="${pathD}" fill="none" stroke="#0D9488" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>

        <!-- Data circles & labels -->
        ${points.map(pt => `
          <g>
            <circle cx="${pt.x}" cy="${pt.y}" r="5" fill="#0D9488" stroke="var(--bg-surface)" stroke-width="2.5" />
            <text x="${pt.x}" y="${pt.y - 12}" fill="var(--text-main)" font-size="11" font-weight="700" text-anchor="middle">
              ${pt.weight}
            </text>
            <text x="${pt.x}" y="${height - padY + 16}" fill="var(--text-muted)" font-size="10" text-anchor="middle">
              ${pt.date.slice(5)}
            </text>
          </g>
        `).join('')}
      </svg>
    `;
  }

  // --- ADD / EDIT PET MODAL HANDLING ---
  function openAddPetModal() {
    elements.petModalTitle.textContent = 'Add New Pet';
    elements.petForm.reset();
    elements.petFormId.value = '';
    elements.initialMedSection.style.display = 'block';
    if (elements.petFormDeleteBtn) {
      elements.petFormDeleteBtn.style.display = 'none';
    }
    selectAvatar('dog');
    openModal(elements.petModal);
    elements.petFormName.focus();
  }

  function openEditPetModal(petId) {
    const pet = state.pets.find(p => p.id == petId) || state.selectedPet;
    if (!pet) return;

    elements.petModalTitle.textContent = `Edit ${pet.name}'s Info`;
    elements.petFormId.value = pet.id;
    elements.petFormName.value = pet.name || '';
    elements.petFormSpecies.value = pet.species || 'Dog';
    elements.petFormBreed.value = pet.breed || '';
    elements.petFormWeight.value = pet.weight || '';
    elements.petFormWeightUnit.value = pet.weight_unit || 'lbs';
    elements.petFormBirthdate.value = pet.birthdate || '';
    elements.petFormGender.value = pet.gender || 'Unknown';
    elements.petFormMicrochip.value = pet.microchip_id || '';
    elements.petFormVet.value = pet.vet_info || '';
    elements.petFormNotes.value = pet.notes || '';
    elements.initialMedSection.style.display = 'none';

    if (elements.petFormDeleteBtn) {
      elements.petFormDeleteBtn.style.display = 'inline-flex';
      elements.petFormDeleteBtn.onclick = () => {
        closeModal(elements.petModal);
        promptDeletePet(pet.id, pet.name);
      };
    }

    selectAvatar(pet.avatar || 'dog');
    openModal(elements.petModal);
  }

  async function handlePetFormSubmit(e) {
    e.preventDefault();

    const id = elements.petFormId.value;
    const payload = {
      name: elements.petFormName.value.trim(),
      species: elements.petFormSpecies.value,
      breed: elements.petFormBreed.value.trim(),
      weight: parseFloat(elements.petFormWeight.value) || 0,
      weight_unit: elements.petFormWeightUnit.value,
      birthdate: elements.petFormBirthdate.value,
      gender: elements.petFormGender.value,
      avatar: state.selectedAvatar,
      microchip_id: elements.petFormMicrochip.value.trim(),
      vet_info: elements.petFormVet.value.trim(),
      notes: elements.petFormNotes.value.trim()
    };

    // If adding a new pet with initial medication
    if (!id && elements.initMedName.value.trim()) {
      payload.medications = [{
        name: elements.initMedName.value.trim(),
        dosage: elements.initMedDosage.value.trim(),
        frequency: elements.initMedFreq.value,
        instructions: elements.initMedInstructions.value.trim(),
        is_active: true
      }];
    }

    try {
      if (id) {
        payload.log_weight_change = true;
        await apiRequest(`/api/pets/${id}`, {
          method: 'PUT',
          body: JSON.stringify(payload)
        });
        showToast(`${payload.name}'s info updated!`);
      } else {
        await apiRequest('/api/pets', {
          method: 'POST',
          body: JSON.stringify(payload)
        });
        showToast(`${payload.name} added to your pet family! 🐾`);
      }

      closeModal(elements.petModal);
      await refreshPets();
      await refreshStats();
      await refreshTodayMeds();

      if (id && state.selectedPet && state.selectedPet.id == id) {
        await refreshSelectedPetDetail();
      }
    } catch (err) {
      console.error(err);
    }
  }

  function selectAvatar(avatarName) {
    state.selectedAvatar = avatarName;
    elements.avatarPicker.querySelectorAll('.avatar-option').forEach(opt => {
      if (opt.getAttribute('data-avatar') === avatarName) {
        opt.classList.add('selected');
      } else {
        opt.classList.remove('selected');
      }
    });
  }

  function promptDeletePet(petId, petName) {
    state.pendingDeletePet = { id: petId, name: petName };
    if (elements.deleteTargetPetName) {
      elements.deleteTargetPetName.textContent = petName;
    }
    openModal(elements.deleteConfirmModal);
  }

  async function executeDeletePet() {
    if (!state.pendingDeletePet) return;
    const { id, name } = state.pendingDeletePet;
    try {
      await apiRequest(`/api/pets/${id}`, { method: 'DELETE' });
      showToast(`${name} has been removed.`);
      closeModal(elements.deleteConfirmModal);
      if (elements.petModal && elements.petModal.classList.contains('active')) {
        closeModal(elements.petModal);
      }
      if (elements.detailModal && elements.detailModal.classList.contains('active')) {
        closeModal(elements.detailModal);
      }
      state.selectedPet = null;
      state.pendingDeletePet = null;
      await refreshPets();
      await refreshStats();
      await refreshTodayMeds();
    } catch (err) {
      console.error(err);
    }
  }

  // --- ADD / EDIT MEDICATION MODAL ---
  function openAddMedicationModal(petId) {
    elements.medModalTitle.textContent = 'Add Medication';
    elements.medicationForm.reset();
    elements.medFormPetId.value = petId;
    elements.medFormId.value = '';
    elements.medFormIsActive.checked = true;

    const todayStr = new Date().toISOString().slice(0, 10);
    elements.medFormStartDate.value = todayStr;

    openModal(elements.medicationModal);
    elements.medFormName.focus();
  }

  function openEditMedicationModal(petId, med) {
    elements.medModalTitle.textContent = `Edit Medication: ${med.name}`;
    elements.medFormPetId.value = petId;
    elements.medFormId.value = med.id;
    elements.medFormName.value = med.name || '';
    elements.medFormDosage.value = med.dosage || '';
    elements.medFormFrequency.value = med.frequency || 'Once daily';
    elements.medFormTimeOfDay.value = med.time_of_day || 'Morning';
    elements.medFormStartDate.value = med.start_date || '';
    elements.medFormEndDate.value = med.end_date || '';
    elements.medFormPrescribingVet.value = med.prescribing_vet || '';
    elements.medFormInstructions.value = med.instructions || '';
    elements.medFormIsActive.checked = med.is_active === 1;

    openModal(elements.medicationModal);
  }

  async function handleMedicationFormSubmit(e) {
    e.preventDefault();
    const petId = elements.medFormPetId.value;
    const medId = elements.medFormId.value;

    const payload = {
      name: elements.medFormName.value.trim(),
      dosage: elements.medFormDosage.value.trim(),
      frequency: elements.medFormFrequency.value,
      time_of_day: elements.medFormTimeOfDay.value,
      start_date: elements.medFormStartDate.value,
      end_date: elements.medFormEndDate.value,
      prescribing_vet: elements.medFormPrescribingVet.value.trim(),
      instructions: elements.medFormInstructions.value.trim(),
      is_active: elements.medFormIsActive.checked
    };

    try {
      if (medId) {
        await apiRequest(`/api/medications/${medId}`, {
          method: 'PUT',
          body: JSON.stringify(payload)
        });
        showToast('Medication updated');
      } else {
        await apiRequest(`/api/pets/${petId}/medications`, {
          method: 'POST',
          body: JSON.stringify(payload)
        });
        showToast('Medication added! 💊');
      }

      closeModal(elements.medicationModal);
      await refreshSelectedPetDetail();
      await refreshPets();
      await refreshTodayMeds();
      await refreshStats();
    } catch (err) {
      console.error(err);
    }
  }

  // --- ADD WEIGHT MODAL ---
  function openAddWeightModal(petId, defaultUnit = 'lbs') {
    elements.weightForm.reset();
    elements.weightFormPetId.value = petId;
    elements.weightFormUnit.value = defaultUnit;
    elements.weightFormDate.value = new Date().toISOString().slice(0, 10);
    openModal(elements.weightModal);
    elements.weightFormVal.focus();
  }

  async function handleWeightFormSubmit(e) {
    e.preventDefault();
    const petId = elements.weightFormPetId.value;
    const payload = {
      weight: parseFloat(elements.weightFormVal.value),
      weight_unit: elements.weightFormUnit.value,
      logged_date: elements.weightFormDate.value,
      notes: elements.weightFormNotes.value.trim()
    };

    try {
      await apiRequest(`/api/pets/${petId}/weights`, {
        method: 'POST',
        body: JSON.stringify(payload)
      });
      showToast('Weight log recorded! 📈');
      closeModal(elements.weightModal);
      await refreshSelectedPetDetail();
      await refreshPets();
    } catch (err) {
      console.error(err);
    }
  }

  // --- EXPORT & IMPORT ---
  async function downloadJsonBackup() {
    try {
      const data = await apiRequest('/api/export');
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `simplypets_backup_${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
      showToast('Backup downloaded successfully! 📁');
    } catch (err) {
      console.error(err);
    }
  }

  async function copyJsonBackup() {
    try {
      const data = await apiRequest('/api/export');
      await navigator.clipboard.writeText(JSON.stringify(data, null, 2));
      showToast('Backup JSON copied to clipboard! 📋');
    } catch (err) {
      showToast('Unable to copy to clipboard', 'error');
    }
  }

  async function handleFileImport(e) {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = async (event) => {
      try {
        const json = JSON.parse(event.target.result);
        const res = await apiRequest('/api/import', {
          method: 'POST',
          body: JSON.stringify(json)
        });
        showToast(res.message || 'Pets imported successfully!');
        closeModal(elements.exportModal);
        await refreshPets();
        await refreshStats();
        await refreshTodayMeds();
      } catch (err) {
        showToast('Invalid JSON file format', 'error');
      }
    };
    reader.readAsText(file);
  }

  async function clearAllData() {
    if (confirm('⚠️ DANGER: This will permanently delete ALL pets, medications, and weight logs. Proceed?')) {
      if (confirm('Are you ABSOLUTELY sure? There is no undo unless you have a backup.')) {
        try {
          await apiRequest('/api/reset', { method: 'POST' });
          showToast('Database reset to empty state.');
          closeModal(elements.exportModal);
          if (elements.detailModal.classList.contains('active')) {
            closeModal(elements.detailModal);
          }
          state.selectedPet = null;
          await refreshPets();
          await refreshStats();
          await refreshTodayMeds();
        } catch (err) {
          console.error(err);
        }
      }
    }
  }

  async function loadSamplePets() {
    try {
      await apiRequest('/api/demo', { method: 'POST' });
      showToast('Sample pets & medications loaded! ✨');
      await refreshPets();
      await refreshStats();
      await refreshTodayMeds();
    } catch (err) {
      console.error(err);
    }
  }

  // --- MODAL UTILITIES ---
  // Stacking counter so a modal opened on top of another (e.g. Edit Pet
  // opened from the pet detail card) always renders in front, regardless
  // of DOM order. Base z-index comes from .modal-backdrop CSS (1000).
  let modalZCounter = 1000;
  function openModal(modalEl) {
    modalZCounter += 1;
    modalEl.style.zIndex = String(modalZCounter);
    modalEl.classList.add('active');
    document.body.style.overflow = 'hidden';
  }

  function closeModal(modalEl) {
    modalEl.classList.remove('active');
    modalEl.style.zIndex = '';
    if (!document.querySelector('.modal-backdrop.active')) {
      document.body.style.overflow = '';
    }
  }

  function closeAllModals() {
    document.querySelectorAll('.modal-backdrop.active').forEach(m => closeModal(m));
  }

  // --- EVENT BINDINGS ---
  function bindEvents() {
    // Theme toggle
    elements.themeToggleBtn.addEventListener('click', toggleTheme);

    // Logout
    if (elements.logoutBtn) {
      elements.logoutBtn.addEventListener('click', handleLogout);
    }

    // Tab switching
    elements.tabPetsBtn.addEventListener('click', () => {
      state.activeTab = 'pets';
      elements.tabPetsBtn.classList.add('active');
      elements.tabScheduleBtn.classList.remove('active');
      elements.petsViewSection.style.display = 'block';
      elements.scheduleViewSection.style.display = 'none';
    });

    elements.tabScheduleBtn.addEventListener('click', () => {
      state.activeTab = 'schedule';
      elements.tabScheduleBtn.classList.add('active');
      elements.tabPetsBtn.classList.remove('active');
      elements.petsViewSection.style.display = 'none';
      elements.scheduleViewSection.style.display = 'block';
      refreshTodayMeds();
    });

    // Search and filters
    elements.searchInput.addEventListener('input', (e) => {
      state.searchQuery = e.target.value;
      renderPetsGrid();
    });

    elements.speciesFilter.addEventListener('change', (e) => {
      state.speciesFilter = e.target.value;
      renderPetsGrid();
    });

    elements.sortFilter.addEventListener('change', (e) => {
      state.sortBy = e.target.value;
      renderPetsGrid();
    });

    // Add Pet Buttons
    elements.openAddPetModalBtn.addEventListener('click', openAddPetModal);
    elements.emptyAddPetBtn.addEventListener('click', openAddPetModal);

    // Sample data buttons
    elements.loadDemoBtn.addEventListener('click', loadSamplePets);
    elements.emptySampleBtn.addEventListener('click', loadSamplePets);

    // Avatar Picker Options
    elements.avatarPicker.querySelectorAll('.avatar-option').forEach(opt => {
      opt.addEventListener('click', () => {
        selectAvatar(opt.getAttribute('data-avatar'));
      });
    });

    // Form Submissions
    elements.petForm.addEventListener('submit', handlePetFormSubmit);
    elements.medicationForm.addEventListener('submit', handleMedicationFormSubmit);
    elements.weightForm.addEventListener('submit', handleWeightFormSubmit);

    // Export Modal & Data management
    elements.exportModalBtn.addEventListener('click', () => openModal(elements.exportModal));
    elements.downloadJsonBtn.addEventListener('click', downloadJsonBackup);
    elements.copyJsonBtn.addEventListener('click', copyJsonBackup);
    elements.triggerImportFileBtn.addEventListener('click', () => elements.importFileInput.click());
    elements.importFileInput.addEventListener('change', handleFileImport);
    elements.clearAllDataBtn.addEventListener('click', clearAllData);

    // Print Button
    elements.printPetBtn.addEventListener('click', () => window.print());

    // Confirm Delete Pet
    if (elements.confirmDeletePetBtn) {
      elements.confirmDeletePetBtn.addEventListener('click', executeDeletePet);
    }

    // Modal Close buttons
    document.querySelectorAll('.close-modal-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const modal = btn.closest('.modal-backdrop');
        if (modal) closeModal(modal);
      });
    });

    // Close modal on backdrop click
    document.querySelectorAll('.modal-backdrop').forEach(modal => {
      modal.addEventListener('click', (e) => {
        if (e.target === modal) closeModal(modal);
      });
    });

    // Keyboard shortcuts
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        closeAllModals();
      }
      // Press '/' to search when not typing in an input
      if (e.key === '/' && !['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName)) {
        e.preventDefault();
        elements.searchInput.focus();
      }
      // Press 'n' for new pet when not typing in an input
      if ((e.key === 'n' || e.key === 'N') && !['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName)) {
        if (!document.querySelector('.modal-backdrop.active')) {
          e.preventDefault();
          openAddPetModal();
        }
      }
    });
  }

  // Helper
  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
