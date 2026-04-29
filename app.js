const stateKey = "finalFocusLevel1";
const ringLength = 2 * Math.PI * 104;
const holdMs = 12000;

const prizes = [
  "10 minutes of guilt-free scrolling",
  "One favorite drink after the next block",
  "A 7-minute walk outside",
  "One episode only after two more blocks",
  "Text one friend that you finished a block",
  "A snack break with no notes open",
  "Pick the music for the next break",
  "Put one coin toward a bigger post-final reward",
];

const funFacts = [
  "Your brain consolidates memory during breaks, so a real break is part of studying.",
  "Starting with a tiny task lowers the activation energy that makes work feel impossible.",
  "Retrieval practice beats rereading when you need knowledge to show up during an exam.",
  "A messy first pass is useful because it gives your brain something concrete to improve.",
  "Short study blocks work best when the goal is specific enough to finish or clearly advance.",
  "Sleep after studying helps stabilize what you learned, especially for finals week.",
  "Practice problems reveal gaps faster than polished notes do.",
];

const defaults = {
  mode: "ready",
  endAt: null,
  totalSeconds: 25 * 60,
  focusMinutes: 25,
  breakMinutes: 5,
  blocks: 0,
  coins: 0,
  streak: 0,
  pendingReward: "",
  intent: "",
  tasks: [],
  agentCollapsed: false,
  careerGoal: "",
  careerPlan: null,
  scheduleDate: "",
  scheduleItems: [],
};

let data = loadState();
let holdStart = 0;
let holdFrame = null;

const els = {
  clock: document.querySelector("#clock"),
  todayDate: document.querySelector("#todayDate"),
  scheduleInput: document.querySelector("#scheduleInput"),
  scheduleAdd: document.querySelector("#scheduleAdd"),
  scheduleList: document.querySelector("#scheduleList"),
  dailyFact: document.querySelector("#dailyFact"),
  focusIntent: document.querySelector("#focusIntent"),
  progressRing: document.querySelector("#progressRing"),
  modeLabel: document.querySelector("#modeLabel"),
  timeLeft: document.querySelector("#timeLeft"),
  startButton: document.querySelector("#startButton"),
  quitButton: document.querySelector("#quitButton"),
  holdFill: document.querySelector("#holdFill"),
  quitReason: document.querySelector("#quitReason"),
  reasonInput: document.querySelector("#reasonInput"),
  confirmQuit: document.querySelector("#confirmQuit"),
  streakCount: document.querySelector("#streakCount"),
  coinCount: document.querySelector("#coinCount"),
  blockCount: document.querySelector("#blockCount"),
  rewardText: document.querySelector("#rewardText"),
  claimReward: document.querySelector("#claimReward"),
  focusMinutes: document.querySelector("#focusMinutes"),
  breakMinutes: document.querySelector("#breakMinutes"),
  notifyToggle: document.querySelector("#notifyToggle"),
  agentToggle: document.querySelector("#agentToggle"),
  agentBody: document.querySelector("#agentBody"),
  taskInput: document.querySelector("#taskInput"),
  planTask: document.querySelector("#planTask"),
  agentSuggestion: document.querySelector("#agentSuggestion"),
  taskList: document.querySelector("#taskList"),
  careerGoal: document.querySelector("#careerGoal"),
  careerBuild: document.querySelector("#careerBuild"),
  careerResult: document.querySelector("#careerResult"),
  completionDialog: document.querySelector("#completionDialog"),
  completionTitle: document.querySelector("#completionTitle"),
  completionCopy: document.querySelector("#completionCopy"),
};

els.progressRing.style.strokeDasharray = ringLength;
hydrate();
setInterval(tick, 250);
tick();

els.startButton.addEventListener("click", () => {
  if (data.mode === "running") return;
  if (data.mode === "breaking") {
    startSession("running", data.focusMinutes);
    return;
  }
  startSession("running", data.focusMinutes);
});

els.focusIntent.addEventListener("input", () => {
  data.intent = els.focusIntent.value.trim();
  saveState();
});

els.focusMinutes.addEventListener("change", () => {
  data.focusMinutes = clampNumber(els.focusMinutes.value, 5, 60, 25);
  if (data.mode === "ready") data.totalSeconds = data.focusMinutes * 60;
  saveState();
  tick();
});

els.breakMinutes.addEventListener("change", () => {
  data.breakMinutes = clampNumber(els.breakMinutes.value, 1, 20, 5);
  saveState();
});

els.scheduleAdd.addEventListener("click", addScheduleItem);

els.scheduleInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    addScheduleItem();
  }
});

els.scheduleList.addEventListener("click", (event) => {
  if (!event.target.matches("button")) return;
  removeScheduleItem(event.target.closest(".schedule-pill")?.dataset.scheduleId);
});

els.notifyToggle.addEventListener("change", async () => {
  if (!els.notifyToggle.checked || !("Notification" in window)) return;
  const permission = await Notification.requestPermission();
  els.notifyToggle.checked = permission === "granted";
});

els.quitButton.addEventListener("pointerdown", beginHold);
els.quitButton.addEventListener("pointerup", cancelHold);
els.quitButton.addEventListener("pointerleave", cancelHold);
els.quitButton.addEventListener("pointercancel", cancelHold);

els.confirmQuit.addEventListener("click", () => {
  const reason = els.reasonInput.value.trim();
  if (reason.length < 4) {
    els.reasonInput.focus();
    return;
  }
  data.mode = "ready";
  data.endAt = null;
  data.streak = 0;
  data.totalSeconds = data.focusMinutes * 60;
  els.quitReason.hidden = true;
  els.reasonInput.value = "";
  saveState();
  tick();
});

els.claimReward.addEventListener("click", () => {
  if (!data.pendingReward) return;
  data.pendingReward = "";
  saveState();
  updateStats();
});

els.agentToggle.addEventListener("click", () => {
  data.agentCollapsed = !data.agentCollapsed;
  saveState();
  renderPlanner();
});

els.planTask.addEventListener("click", addPlannedTask);

els.taskInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    addPlannedTask();
  }
});

els.taskList.addEventListener("click", (event) => {
  const item = event.target.closest(".task-item");
  if (!item) return;

  const taskId = item.dataset.taskId;
  if (event.target.matches("button")) {
    useTask(taskId);
  }
});

els.taskList.addEventListener("change", (event) => {
  if (!event.target.matches("input[type='checkbox']")) return;
  const item = event.target.closest(".task-item");
  completeTask(item.dataset.taskId, event.target.checked);
});

els.careerBuild.addEventListener("click", buildCareerPlan);

els.careerGoal.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    event.preventDefault();
    buildCareerPlan();
  }
});

els.careerResult.addEventListener("click", (event) => {
  if (!event.target.matches("button")) return;
  const step = event.target.closest("li")?.querySelector("span")?.textContent;
  if (!step) return;
  addTasksToPlanner([step]);
});

window.addEventListener("keydown", (event) => {
  if (event.code === "Space" && !isTyping(event.target)) {
    event.preventDefault();
    els.startButton.click();
  }
});

window.addEventListener(
  "wheel",
  (event) => {
    if (data.mode === "running") event.preventDefault();
  },
  { passive: false },
);

window.addEventListener(
  "touchmove",
  (event) => {
    if (data.mode === "running") event.preventDefault();
  },
  { passive: false },
);

function hydrate() {
  syncScheduleDate();
  els.focusIntent.value = data.intent;
  els.focusMinutes.value = data.focusMinutes;
  els.breakMinutes.value = data.breakMinutes;
  els.careerGoal.value = data.careerGoal;
  renderDayPanel();
  renderPlanner();
  renderCareerPlan();
  updateStats();
}

function tick() {
  const now = Date.now();
  els.clock.textContent = new Intl.DateTimeFormat([], {
    hour: "numeric",
    minute: "2-digit",
  }).format(now);
  els.todayDate.textContent = formatToday(now);

  if ((data.mode === "running" || data.mode === "breaking") && now >= data.endAt) {
    completeSession();
  }

  const remaining = getRemainingSeconds();
  const total = Math.max(data.totalSeconds, 1);
  const elapsed = total - remaining;
  const progress = Math.min(Math.max(elapsed / total, 0), 1);

  els.timeLeft.textContent = formatTime(remaining);
  els.progressRing.style.strokeDashoffset = ringLength * progress;
  els.modeLabel.textContent = modeText();
  els.startButton.textContent = buttonText();
  els.startButton.disabled = data.mode === "running";
  els.quitButton.disabled = data.mode === "ready";
  document.body.classList.toggle("running", data.mode === "running");
  document.body.classList.toggle("breaking", data.mode === "breaking");
}

function renderDayPanel() {
  els.todayDate.textContent = formatToday(Date.now());
  els.dailyFact.textContent = funFacts[getDayOfYear(new Date()) % funFacts.length];
  els.scheduleList.innerHTML = "";

  if (data.scheduleItems.length === 0) {
    const empty = document.createElement("span");
    empty.className = "empty-schedule";
    empty.textContent = "No schedule added yet.";
    els.scheduleList.append(empty);
    return;
  }

  data.scheduleItems.forEach((item) => {
    const pill = document.createElement("span");
    pill.className = "schedule-pill";
    pill.dataset.scheduleId = item.id;

    const title = document.createElement("span");
    title.textContent = item.title;

    const button = document.createElement("button");
    button.type = "button";
    button.ariaLabel = `Remove ${item.title}`;
    button.textContent = "x";

    pill.append(title, button);
    els.scheduleList.append(pill);
  });
}

function addScheduleItem() {
  const title = els.scheduleInput.value.trim().replace(/\s+/g, " ");
  if (title.length < 2) {
    els.scheduleInput.focus();
    return;
  }

  data.scheduleItems = [
    ...data.scheduleItems,
    {
      id: crypto.randomUUID(),
      title,
    },
  ].slice(0, 6);
  els.scheduleInput.value = "";
  saveState();
  renderDayPanel();
}

function removeScheduleItem(scheduleId) {
  if (!scheduleId) return;
  data.scheduleItems = data.scheduleItems.filter((item) => item.id !== scheduleId);
  saveState();
  renderDayPanel();
}

function syncScheduleDate() {
  const todayKey = new Date().toISOString().slice(0, 10);
  if (data.scheduleDate === todayKey) return;
  data.scheduleDate = todayKey;
  data.scheduleItems = [];
  saveState();
}

function startSession(mode, minutes) {
  const safeMinutes = clampNumber(minutes, 1, 60, 25);
  data.mode = mode;
  data.totalSeconds = safeMinutes * 60;
  data.endAt = Date.now() + data.totalSeconds * 1000;
  els.quitReason.hidden = true;
  saveState();
  tick();
}

function completeSession() {
  if (data.mode === "running") {
    data.blocks += 1;
    data.streak += 1;
    data.coins += 3;
    data.pendingReward = prizes[Math.floor(Math.random() * prizes.length)];
    notify("Focus block complete", `Prize unlocked: ${data.pendingReward}`);
    showCompletion("Prize unlocked", data.pendingReward);
    startSession("breaking", data.breakMinutes);
  } else {
    data.mode = "ready";
    data.endAt = null;
    data.totalSeconds = data.focusMinutes * 60;
    notify("Break complete", "Start the next tiny finals target.");
  }
  saveState();
  updateStats();
}

function beginHold() {
  if (data.mode === "ready") return;
  holdStart = performance.now();
  const draw = (now) => {
    const percent = Math.min(((now - holdStart) / holdMs) * 100, 100);
    els.holdFill.style.setProperty("--hold", `${percent}%`);
    if (percent >= 100) {
      cancelHold();
      els.quitReason.hidden = false;
      els.reasonInput.focus();
      return;
    }
    holdFrame = requestAnimationFrame(draw);
  };
  holdFrame = requestAnimationFrame(draw);
}

function cancelHold() {
  if (holdFrame) cancelAnimationFrame(holdFrame);
  holdFrame = null;
  holdStart = 0;
  els.holdFill.style.setProperty("--hold", "0%");
}

function updateStats() {
  els.streakCount.textContent = data.streak;
  els.coinCount.textContent = data.coins;
  els.blockCount.textContent = data.blocks;
  els.rewardText.textContent = data.pendingReward
    ? data.pendingReward
    : "Complete one focus block to unlock your first prize.";
  els.claimReward.disabled = !data.pendingReward;
}

function addPlannedTask() {
  const rawTask = els.taskInput.value.trim();
  if (rawTask.length < 3) {
    els.taskInput.focus();
    return;
  }

  const steps = makeStartableSteps(rawTask);
  addTasksToPlanner(steps, rawTask);
  els.taskInput.value = "";
}

function addTasksToPlanner(steps, source = "career plan") {
  data.tasks = [
    ...steps.map((title) => ({
      id: crypto.randomUUID(),
      title,
      done: false,
      source,
    })),
    ...data.tasks,
  ].slice(0, 10);
  saveState();
  renderPlanner();
}

function renderPlanner() {
  const openTasks = data.tasks.filter((task) => !task.done);
  const nextTask = openTasks[0];

  document.querySelector(".planner-agent").classList.toggle("collapsed", data.agentCollapsed);
  els.agentToggle.textContent = data.agentCollapsed ? "Open" : "Min";
  els.agentToggle.setAttribute("aria-expanded", String(!data.agentCollapsed));
  els.agentSuggestion.textContent = nextTask
    ? `Suggested next target: ${nextTask.title}`
    : "Add one messy task and I will make it startable.";

  els.taskList.innerHTML = "";
  data.tasks.forEach((task) => {
    const item = document.createElement("div");
    item.className = `task-item${task.done ? " done" : ""}`;
    item.dataset.taskId = task.id;

    const checkbox = document.createElement("input");
    checkbox.type = "checkbox";
    checkbox.checked = task.done;
    checkbox.ariaLabel = `Complete ${task.title}`;

    const title = document.createElement("span");
    title.textContent = task.title;

    const button = document.createElement("button");
    button.type = "button";
    button.textContent = "Use";
    button.disabled = task.done;

    item.append(checkbox, title, button);
    els.taskList.append(item);
  });
}

function useTask(taskId) {
  const task = data.tasks.find((item) => item.id === taskId);
  if (!task || task.done) return;
  data.intent = task.title;
  els.focusIntent.value = task.title;
  saveState();
  renderPlanner();
}

function completeTask(taskId, done) {
  const task = data.tasks.find((item) => item.id === taskId);
  if (!task) return;
  const wasDone = task.done;
  task.done = done;
  if (!wasDone && done) data.coins += 1;
  saveState();
  renderPlanner();
  updateStats();
}

function makeStartableSteps(task) {
  const cleanTask = task.replace(/\s+/g, " ").trim();
  const lowerTask = cleanTask.toLowerCase();

  if (lowerTask.includes("final") || lowerTask.includes("exam")) {
    return [
      `Open materials for ${cleanTask}`,
      `List the 3 weakest topics for ${cleanTask}`,
      `Do one practice problem for ${cleanTask}`,
    ];
  }

  if (lowerTask.includes("read") || lowerTask.includes("chapter")) {
    return [
      `Open ${cleanTask}`,
      `Read 3 pages and mark confusing parts`,
      `Write 5 recall questions from ${cleanTask}`,
    ];
  }

  if (lowerTask.includes("write") || lowerTask.includes("essay") || lowerTask.includes("paper")) {
    return [
      `Open the draft for ${cleanTask}`,
      `Write the roughest 5 bullet outline`,
      `Draft one imperfect paragraph for ${cleanTask}`,
    ];
  }

  return [
    `Open everything needed for ${cleanTask}`,
    `Write the first 3 actions for ${cleanTask}`,
    `Do the smallest 10-minute piece of ${cleanTask}`,
  ];
}

function buildCareerPlan() {
  const goal = els.careerGoal.value.trim();
  if (goal.length < 3) {
    els.careerGoal.focus();
    return;
  }
  data.careerGoal = goal;
  data.careerPlan = pickCareerPlan(goal);
  saveState();
  renderCareerPlan();
}

function renderCareerPlan() {
  if (!data.careerPlan) {
    els.careerResult.innerHTML =
      '<p>Type a career goal and I will attach a resource plus first study milestones.</p>';
    return;
  }

  const plan = data.careerPlan;
  els.careerResult.innerHTML = "";

  const resource = document.createElement("div");
  resource.className = "resource-card";

  const link = document.createElement("a");
  link.href = plan.url;
  link.target = "_blank";
  link.rel = "noreferrer";
  link.textContent = plan.resource;

  const summary = document.createElement("p");
  summary.textContent = plan.summary;

  resource.append(link, summary);

  const steps = document.createElement("ul");
  steps.className = "career-steps";
  plan.steps.forEach((step) => {
    const item = document.createElement("li");
    const label = document.createElement("span");
    label.textContent = step;
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = "Add";
    item.append(label, button);
    steps.append(item);
  });

  els.careerResult.append(resource, steps);
}

function pickCareerPlan(goal) {
  const normalized = goal.toLowerCase();
  if (
    normalized.includes("coding interview") ||
    normalized.includes("software engineer") ||
    normalized.includes("leetcode") ||
    normalized.includes("algorithm")
  ) {
    return {
      goal,
      resource: "jwasham/coding-interview-university",
      url: "https://github.com/jwasham/coding-interview-university",
      summary:
        "A multi-month computer science and technical interview study plan for software engineering interviews.",
      steps: [
        "Choose one interview language and set up the practice environment",
        "Study Big-O and solve 3 complexity analysis drills",
        "Review arrays and strings, then solve 2 easy problems",
        "Review linked lists, stacks, and queues",
        "Start a daily coding-question practice log",
      ],
    };
  }

  return {
    goal,
    resource: "roadmap.sh",
    url: "https://roadmap.sh/",
    summary:
      "A collection of role-based developer roadmaps. Use it to choose a track before building a detailed study plan.",
    steps: [
      `Find the closest roadmap for ${goal}`,
      `Write the top 5 missing skills for ${goal}`,
      `Pick one beginner resource for the first missing skill`,
      `Schedule the first 25-minute learning block for ${goal}`,
    ],
  };
}

function showCompletion(title, copy) {
  els.completionTitle.textContent = title;
  els.completionCopy.textContent = copy;
  if (typeof els.completionDialog.showModal === "function") {
    els.completionDialog.showModal();
  }
}

function notify(title, body) {
  if (!els.notifyToggle.checked || !("Notification" in window)) return;
  if (Notification.permission === "granted") {
    new Notification(title, { body });
  }
}

function getRemainingSeconds() {
  if (data.mode === "ready" || !data.endAt) return data.focusMinutes * 60;
  return Math.max(Math.ceil((data.endAt - Date.now()) / 1000), 0);
}

function formatToday(date) {
  return new Intl.DateTimeFormat([], {
    weekday: "long",
    month: "short",
    day: "numeric",
  }).format(date);
}

function getDayOfYear(date) {
  const start = new Date(date.getFullYear(), 0, 0);
  const diff = date - start + (start.getTimezoneOffset() - date.getTimezoneOffset()) * 60000;
  return Math.floor(diff / 86400000);
}

function modeText() {
  if (data.mode === "running") return data.intent ? "Locked in" : "Focus";
  if (data.mode === "breaking") return "Break";
  return "Ready";
}

function buttonText() {
  if (data.mode === "breaking") return "Skip to focus";
  if (data.mode === "running") return "Focus running";
  return "Start focus";
}

function formatTime(seconds) {
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return `${String(minutes).padStart(2, "0")}:${String(rest).padStart(2, "0")}`;
}

function loadState() {
  try {
    return { ...defaults, ...JSON.parse(localStorage.getItem(stateKey)) };
  } catch {
    return { ...defaults };
  }
}

function saveState() {
  localStorage.setItem(stateKey, JSON.stringify(data));
}

function clampNumber(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(Math.max(number, min), max);
}

function isTyping(target) {
  return target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement;
}
