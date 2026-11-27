import {
  PiAirplane,
  PiAlien,
  PiBookOpen,
  PiBriefcase,
  PiCalendar,
  PiCamera,
  PiChartBar,
  PiChartLine,
  PiChatCircle,
  PiCheckCircle,
  PiCloudArrowUp,
  PiCodeSimple,
  PiDatabase,
  PiDrop,
  PiEnvelope,
  PiEnvelopeSimple,
  PiFacebookLogo,
  PiFileDoc,
  PiFolder,
  PiGameController,
  PiGithubLogo,
  PiGlobe,
  PiHeart,
  PiInfinity,
  PiLightning,
  PiMagnifyingGlass,
  PiMapPin,
  PiMoon,
  PiMusicNote,
  PiNewspaper,
  PiNotePencil,
  PiNotebook,
  PiPackage,
  PiPlay,
  PiPresentationChart,
  PiRobot,
  PiRocket,
  PiSmiley,
  PiSparkle,
  PiStarFour,
  PiThreadsLogo,
  PiTrendDown,
  PiTwitterLogo,
  PiUsersThree,
  PiWaveform,
  PiWind,
  PiWindowsLogo
} from 'react-icons/pi';

import type { IconType } from 'react-icons';

export interface Bookmark {
  section: string;
  label: string;
  description: string;
  href: string;
  badge?: string;
  icon: IconType;
}

const ICONS: Record<string, IconType> = {
  PiAirplane: PiAirplane,
  PiAlien: PiAlien,
  PiBookOpen: PiBookOpen,
  PiBriefcase: PiBriefcase,
  PiCalendar: PiCalendar,
  PiCamera: PiCamera,
  PiChartBar: PiChartBar,
  PiChartLine: PiChartLine,
  PiChatCircle: PiChatCircle,
  PiCheckCircle: PiCheckCircle,
  PiCloudArrowUp: PiCloudArrowUp,
  PiCodeSimple: PiCodeSimple,
  PiDatabase: PiDatabase,
  PiDrop: PiDrop,
  PiEnvelope: PiEnvelope,
  PiEnvelopeSimple: PiEnvelopeSimple,
  PiFacebookLogo: PiFacebookLogo,
  PiFileDoc: PiFileDoc,
  PiFolder: PiFolder,
  PiGameController: PiGameController,
  PiGithubLogo: PiGithubLogo,
  PiGlobe: PiGlobe,
  PiHeart: PiHeart,
  PiInfinity: PiInfinity,
  PiLightning: PiLightning,
  PiMagnifyingGlass: PiMagnifyingGlass,
  PiMapPin: PiMapPin,
  PiMoon: PiMoon,
  PiMusicNote: PiMusicNote,
  PiNewspaper: PiNewspaper,
  PiNotePencil: PiNotePencil,
  PiNotebook: PiNotebook,
  PiPackage: PiPackage,
  PiPlay: PiPlay,
  PiPresentationChart: PiPresentationChart,
  PiRobot: PiRobot,
  PiRocket: PiRocket,
  PiSmiley: PiSmiley,
  PiSparkle: PiSparkle,
  PiStarFour: PiStarFour,
  PiThreadsLogo: PiThreadsLogo,
  PiTrendDown: PiTrendDown,
  PiTwitterLogo: PiTwitterLogo,
  PiUsersThree: PiUsersThree,
  PiWaveform: PiWaveform,
  PiWind: PiWind,
  PiWindowsLogo: PiWindowsLogo
};

// Migrated from omni/packages/web apps.csv bookmark rows.

export const BOOKMARKS: Bookmark[] = [
  {
    section: 'Agents',
    label: 'Claude',
    description: 'Anthropic',
    href: 'https://claude.ai/',
    icon: ICONS['PiStarFour'],
    badge: 'Chat'
  },
  {
    section: 'Agents',
    label: 'ChatGPT',
    description: 'OpenAI',
    href: 'https://chatgpt.com',
    icon: ICONS['PiStarFour'],
    badge: 'Chat'
  },
  {
    section: 'Agents',
    label: 'Qwen',
    description: 'Alibaba Cloud',
    href: 'https://qwen.ai',
    icon: ICONS['PiStarFour'],
    badge: 'Chat'
  },
  {
    section: 'Agents',
    label: 'Kimi',
    description: 'Moonshot AI',
    href: 'https://kimi.moonshot.cn',
    icon: ICONS['PiMoon'],
    badge: 'Chat'
  },
  {
    section: 'Agents',
    label: 'Perplexity',
    description: 'AI Search',
    href: 'https://www.perplexity.ai',
    icon: ICONS['PiMagnifyingGlass'],
    badge: 'Research'
  },
  {
    section: 'Agents',
    label: 'Gemini',
    description: 'Google',
    href: 'https://gemini.google.com/app',
    icon: ICONS['PiSparkle']
  },
  {
    section: 'Agents',
    label: 'Grok',
    description: 'xAI',
    href: 'https://grok.com',
    icon: ICONS['PiLightning']
  },
  {
    section: 'Agents',
    label: 'Copilot',
    description: 'Microsoft',
    href: 'https://copilot.microsoft.com',
    icon: ICONS['PiWindowsLogo']
  },
  {
    section: 'Agents',
    label: 'DeepSeek',
    description: 'DeepSeek',
    href: 'https://chat.deepseek.com',
    icon: ICONS['PiDrop']
  },
  {
    section: 'Agents',
    label: 'Mistral',
    description: 'Mistral AI',
    href: 'https://chat.mistral.ai',
    icon: ICONS['PiWind']
  },
  {
    section: 'Agents',
    label: 'Meta AI',
    description: 'Meta',
    href: 'https://www.meta.ai',
    icon: ICONS['PiInfinity']
  },
  {
    section: 'Agents',
    label: 'HuggingChat',
    description: 'HuggingFace',
    href: 'https://huggingface.co/chat',
    icon: ICONS['PiSmiley']
  },
  {
    section: 'Agents',
    label: 'Poe',
    description: 'Quora',
    href: 'https://poe.com',
    icon: ICONS['PiChatCircle']
  },
  {
    section: 'Agents',
    label: 'Cohere',
    description: 'Cohere',
    href: 'https://coral.cohere.com',
    icon: ICONS['PiWaveform']
  },
  {
    section: 'Code',
    label: 'GitHub',
    description: 'Git',
    href: 'https://github.com',
    icon: ICONS['PiGithubLogo']
  },
  {
    section: 'Code',
    label: 'Renovate',
    description: 'Code',
    href: 'https://developer.mend.io',
    icon: ICONS['PiRobot']
  },
  {
    section: 'Code',
    label: 'Vercel',
    description: 'Deployment',
    href: 'https://vercel.com',
    icon: ICONS['PiGlobe']
  },
  {
    section: 'Code',
    label: 'Supabase',
    description: 'Database',
    href: 'https://supabase.com',
    icon: ICONS['PiDatabase']
  },
  {
    section: 'Google Workspace',
    label: 'Calendar',
    description: 'Calendar',
    href: 'https://calendar.google.com',
    icon: ICONS['PiCalendar']
  },
  {
    section: 'Google Workspace',
    label: 'Docs',
    description: 'Word',
    href: 'https://docs.google.com',
    icon: ICONS['PiNotePencil']
  },
  {
    section: 'Google Workspace',
    label: 'Drive',
    description: 'OneDrive',
    href: 'https://drive.google.com',
    icon: ICONS['PiFolder']
  },
  {
    section: 'Google Workspace',
    label: 'Gmail',
    description: 'Email',
    href: 'https://gmail.com',
    icon: ICONS['PiEnvelope']
  },
  {
    section: 'Google Workspace',
    label: 'Maps',
    description: 'Maps',
    href: 'https://maps.google.com',
    icon: ICONS['PiMapPin']
  },
  {
    section: 'Google Workspace',
    label: 'Sheets',
    description: 'Excel',
    href: 'https://sheets.google.com',
    icon: ICONS['PiChartBar']
  },
  {
    section: 'Google Workspace',
    label: 'Slides',
    description: 'PowerPoint',
    href: 'https://slides.google.com',
    icon: ICONS['PiPlay']
  },
  {
    section: 'Google Workspace',
    label: 'Tasks',
    description: 'ToDo',
    href: 'https://tasks.google.com',
    icon: ICONS['PiCheckCircle']
  },
  {
    section: 'Microsoft Workspace',
    label: 'Outlook',
    description: 'Gmail',
    href: 'https://outlook.com',
    icon: ICONS['PiEnvelopeSimple']
  },
  {
    section: 'Microsoft Workspace',
    label: 'Calendar',
    description: 'Calendar',
    href: 'https://outlook.live.com/calendar',
    icon: ICONS['PiCalendar']
  },
  {
    section: 'Microsoft Workspace',
    label: 'OneDrive',
    description: 'Drive',
    href: 'https://onedrive.live.com',
    icon: ICONS['PiCloudArrowUp']
  },
  {
    section: 'Microsoft Workspace',
    label: 'Word',
    description: 'Docs',
    href: 'https://www.microsoft365.com/launch/word',
    icon: ICONS['PiFileDoc']
  },
  {
    section: 'Microsoft Workspace',
    label: 'Excel',
    description: 'Sheets',
    href: 'https://www.microsoft365.com/launch/excel',
    icon: ICONS['PiChartBar']
  },
  {
    section: 'Microsoft Workspace',
    label: 'PowerPoint',
    description: 'Slides',
    href: 'https://www.microsoft365.com/launch/powerpoint',
    icon: ICONS['PiPresentationChart']
  },
  {
    section: 'Microsoft Workspace',
    label: 'To Do',
    description: 'Tasks',
    href: 'https://to-do.office.com/tasks/',
    icon: ICONS['PiCheckCircle']
  },
  {
    section: 'Microsoft Workspace',
    label: 'Teams',
    description: 'Chat',
    href: 'https://teams.microsoft.com',
    icon: ICONS['PiUsersThree']
  },
  {
    section: 'Microsoft Workspace',
    label: 'OneNote',
    description: 'Keep',
    href: 'https://www.onenote.com',
    icon: ICONS['PiNotebook']
  },
  {
    section: 'Microsoft Workspace',
    label: 'Microsoft 365',
    description: 'Workspace',
    href: 'https://www.microsoft365.com',
    icon: ICONS['PiWindowsLogo']
  },
  {
    section: 'Messaging',
    label: 'Discord',
    description: 'Messaging',
    href: 'https://discord.com',
    icon: ICONS['PiGameController']
  },
  {
    section: 'Messaging',
    label: 'Messenger',
    description: 'Messaging',
    href: 'https://www.messenger.com',
    icon: ICONS['PiHeart']
  },
  {
    section: 'Messaging',
    label: 'Slack',
    description: 'Messaging',
    href: 'https://slack.com',
    icon: ICONS['PiCodeSimple']
  },
  {
    section: 'Messaging',
    label: 'Telegram',
    description: 'Messaging',
    href: 'https://web.telegram.org/',
    icon: ICONS['PiAirplane']
  },
  {
    section: 'Music',
    label: 'Spotify',
    description: 'Music',
    href: 'https://open.spotify.com',
    icon: ICONS['PiMusicNote']
  },
  {
    section: 'Music',
    label: 'YouTube',
    description: 'Videos',
    href: 'https://youtube.com',
    icon: ICONS['PiPlay']
  },
  {
    section: 'Social',
    label: 'Facebook',
    description: 'Social network',
    href: 'https://facebook.com',
    icon: ICONS['PiFacebookLogo']
  },
  {
    section: 'Social',
    label: 'Instagram',
    description: 'Photos',
    href: 'https://instagram.com',
    icon: ICONS['PiCamera']
  },
  {
    section: 'Social',
    label: 'Reddit',
    description: 'Social network',
    href: 'https://reddit.com',
    icon: ICONS['PiAlien']
  },
  {
    section: 'Social',
    label: 'Threads',
    description: 'Social network',
    href: 'https://threads.net',
    icon: ICONS['PiThreadsLogo']
  },
  {
    section: 'Social',
    label: 'Tiktok',
    description: 'Social network',
    href: 'https://www.tiktok.com',
    icon: ICONS['PiMusicNote']
  },
  {
    section: 'Social',
    label: 'X',
    description: 'Social network',
    href: 'https://x.com',
    icon: ICONS['PiTwitterLogo']
  },
  {
    section: 'Work',
    label: 'LinkedIn',
    description: 'Social network',
    href: 'https://linkedin.com',
    icon: ICONS['PiBriefcase']
  },
  {
    section: 'Work',
    label: 'Hacker News',
    description: 'News',
    href: 'https://news.ycombinator.com',
    icon: ICONS['PiNewspaper']
  },
  {
    section: 'Work',
    label: 'Indie Hackers',
    description: 'News',
    href: 'https://www.indiehackers.com',
    icon: ICONS['PiCodeSimple']
  },
  {
    section: 'Work',
    label: 'Product Hunt',
    description: 'News',
    href: 'https://www.producthunt.com',
    icon: ICONS['PiPackage']
  },
  {
    section: 'Work',
    label: 'Y Combinator',
    description: 'Startup',
    href: 'https://www.ycombinator.com',
    icon: ICONS['PiLightning']
  },
  {
    section: 'Work',
    label: 'BetaList',
    description: 'Launch',
    href: 'https://betalist.com',
    icon: ICONS['PiRocket']
  },
  {
    section: 'Work',
    label: 'TechCrunch',
    description: 'News',
    href: 'https://techcrunch.com',
    icon: ICONS['PiNewspaper']
  },
  {
    section: 'Work',
    label: 'Starter Story',
    description: 'Stories',
    href: 'https://www.starterstory.com',
    icon: ICONS['PiBookOpen']
  },
  {
    section: 'Work',
    label: 'Failory',
    description: 'Stories',
    href: 'https://www.failory.com',
    icon: ICONS['PiTrendDown']
  },
  {
    section: 'Work',
    label: 'Wellfound',
    description: 'Jobs',
    href: 'https://wellfound.com',
    icon: ICONS['PiBriefcase']
  },
  {
    section: 'Work',
    label: 'Crunchbase',
    description: 'Data',
    href: 'https://www.crunchbase.com',
    icon: ICONS['PiChartLine']
  },
  {
    section: 'Work',
    label: 'Hashnode',
    description: 'Blogging',
    href: 'https://hashnode.com',
    icon: ICONS['PiCodeSimple']
  }
];
