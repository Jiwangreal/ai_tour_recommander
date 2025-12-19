import common from '@ohos.app.ability.common';
import { BusinessError } from '@kit.BasicServicesKit';

export interface AppConfig {
  amapKey?: string;
  amapBaseUrl?: string;
  llmApiKey?: string;
  llmBaseUrl?: string;
  llmModel?: string;
  llmSystemPrompt?: string;
  llmEnableSearch?: boolean;
  defaultCity?: string;
  networkTimeout?: number;
  mockMode?: boolean;
}

export interface ConfigResult {
  config: AppConfig;
  source: 'file' | 'fallback';
  message?: string;
}

const DEFAULT_CONFIG: AppConfig = {
  amapBaseUrl: 'https://restapi.amap.com/v3',
  llmBaseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
  llmModel: 'qwen-plus',
  llmSystemPrompt: '你是一个本地生活与旅行路线推荐助手，请结合给定的POI列表给出简洁、可执行的吃喝玩乐方案，并给出推荐理由与行程顺序。',
  defaultCity: '北京',
  networkTimeout: 12000,
  mockMode: true,
};

function toUtf8String(data: Uint8Array): string {
  // 手动转换Uint8Array到字符串
  let result = '';
  for (let i = 0; i < data.length; i++) {
    result += String.fromCharCode(data[i]);
  }
  return result;
}

export async function loadConfig(context: common.UIAbilityContext): Promise<ConfigResult> {
  try {
    const byteArray = await context.resourceManager.getRawFileContent('config.json');
    const text = toUtf8String(byteArray);
    const parsed = JSON.parse(text);
    const merged: AppConfig = { ...DEFAULT_CONFIG, ...parsed, mockMode: false };
    return { config: merged, source: 'file' };
  } catch (error) {
    const err = error as BusinessError | Error;
    const message = err?.message ?? JSON.stringify(err);
    return {
      config: { ...DEFAULT_CONFIG, mockMode: true },
      source: 'fallback',
      message,
    };
  }
}

export function missingCriticalKeys(config: AppConfig): string | undefined {
  if (!config.amapKey) {
    return '缺少高德地图密钥（amapKey）';
  }
  if (!config.llmApiKey) {
    return '缺少大模型密钥（llmApiKey）';
  }
  return undefined;
}
