// App mock items data
const playlistData = {
  live: {
    title: "Loveworld Radio Broadcast",
    subtitle: "LIVE BROADCAST",
    art: "📻",
    totalTime: "LIVE",
    metadataSequence: [
      "Loveworld Radio • Live Stream",
      "Pastor Chris • Pastor Chris Teaching",
      "Loveworld Worship • Holy Spirit Live",
      "Loveworld Radio • Airing Live Sermon"
    ]
  },
  pod1: {
    title: "Building the Future (Ep. 42)",
    subtitle: "RADIO OVER PODCAST",
    art: "🎙️",
    totalTime: "24:15",
    durationSeconds: 1455
  },
  pod2: {
    title: "Acoustic Melodies Showcase",
    subtitle: "WORSHIP & PRAISE",
    art: "🎙️",
    totalTime: "18:40",
    durationSeconds: 1120
  }
};

// Current Player State
let currentItemKey = 'live';
let isPlaying = false;
let elapsedSeconds = 0;
let progressInterval = null;
let metadataInterval = null;
let metadataIndex = 0;

// Element Queries
const mockupTogglePlay = document.getElementById('mockup-toggle-play');
const mockupBtnText = document.getElementById('mockup-btn-text');
const mockupMetadata = document.getElementById('mockup-metadata');
const appMockup = document.getElementById('app-mockup');

const demoBtnPlay = document.getElementById('demo-btn-play');
const demoTitle = document.getElementById('demo-title');
const demoSubtitle = document.getElementById('demo-subtitle');
const demoArt = document.getElementById('demo-art');
const demoTimeElapsed = document.getElementById('demo-time-elapsed');
const demoTimeTotal = document.getElementById('demo-time-total');
const demoProgressFill = document.getElementById('demo-progress-fill');

// Init state
updatePlayerUI();

// Event Listeners
mockupTogglePlay.addEventListener('click', togglePlayback);
demoBtnPlay.addEventListener('click', togglePlayback);

// Actions
function togglePlayback() {
  isPlaying = !isPlaying;
  
  if (isPlaying) {
    mockupBtnText.textContent = "PAUSE";
    demoBtnPlay.textContent = "PAUSE";
    appMockup.classList.add('animate-waveform');
    
    // Playback progression
    if (currentItemKey === 'live') {
      mockupMetadata.textContent = playlistData.live.metadataSequence[0];
      startLiveMetadataSimulation();
    } else {
      startPodcastProgressSimulation();
    }
  } else {
    mockupBtnText.textContent = "PLAY";
    demoBtnPlay.textContent = "PLAY";
    appMockup.classList.remove('animate-waveform');
    
    clearInterval(progressInterval);
    clearInterval(metadataInterval);
    
    if (currentItemKey === 'live') {
      mockupMetadata.textContent = "STREAM PAUSED";
    }
  }
}

function selectDemoItem(key) {
  // Clear previous
  isPlaying = false;
  clearInterval(progressInterval);
  clearInterval(metadataInterval);
  elapsedSeconds = 0;
  mockupBtnText.textContent = "PLAY";
  demoBtnPlay.textContent = "PLAY";
  appMockup.classList.remove('animate-waveform');
  
  currentItemKey = key;
  
  // Update playlist active item style
  document.querySelectorAll('.playlist-item').forEach(item => {
    item.classList.remove('active');
  });
  document.getElementById(`item-${key}`).classList.add('active');
  
  updatePlayerUI();
}

function updatePlayerUI() {
  const item = playlistData[currentItemKey];
  demoTitle.textContent = item.title;
  demoSubtitle.textContent = item.subtitle;
  demoArt.textContent = item.art;
  demoTimeTotal.textContent = item.totalTime;
  
  if (currentItemKey === 'live') {
    mockupMetadata.textContent = "TAP PLAY TO CONNECT";
    demoTimeElapsed.textContent = "0:00";
    demoProgressFill.style.width = "0%";
  } else {
    mockupMetadata.textContent = "READY TO PLAY";
    updateProgressBarUI();
  }
}

function updateProgressBarUI() {
  const item = playlistData[currentItemKey];
  demoTimeElapsed.textContent = formatTime(elapsedSeconds);
  const percentage = (elapsedSeconds / item.durationSeconds) * 100;
  demoProgressFill.style.width = `${percentage}%`;
}

function startLiveMetadataSimulation() {
  metadataIndex = 0;
  metadataInterval = setInterval(() => {
    metadataIndex = (metadataIndex + 1) % playlistData.live.metadataSequence.length;
    mockupMetadata.textContent = playlistData.live.metadataSequence[metadataIndex];
  }, 4000);
}

function startPodcastProgressSimulation() {
  const item = playlistData[currentItemKey];
  progressInterval = setInterval(() => {
    elapsedSeconds++;
    if (elapsedSeconds >= item.durationSeconds) {
      elapsedSeconds = 0;
      togglePlayback();
    }
    updateProgressBarUI();
  }, 1000);
}

function formatTime(totalSeconds) {
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
}
