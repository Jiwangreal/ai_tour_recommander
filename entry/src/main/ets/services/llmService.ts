import { httpPost, HttpError } from '../common/httpClient';
import type { AppConfig } from '../common/config';
import type { PoiItem } from './types';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'LlmService';

export interface LlmChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface LlmChatRequest {
  model: string;
  messages: LlmChatMessage[];
  temperature?: number;
  max_tokens?: number;
  enable_search?: boolean;
}

export interface LlmChatResponse {
  id?: string;
  object?: string;
  created?: number;
  model?: string;
  choices?: Array<{
    index?: number;
    message?: {
      role?: string;
      content?: string;
    };
    finish_reason?: string;
  }>;
  error?: {
    message: string;
    type?: string;
  };
}

/**
 * 大模型服务（兼容OpenAI格式）
 */
export class LlmService {
  private config: AppConfig;

  constructor(config: AppConfig) {
    this.config = config;
  }

  /**
   * 调用大模型生成推荐内容
   */
  async generateRecommendation(
    userQuery: string,
    pois: PoiItem[],
    context?: string
  ): Promise<string> {
    if (!this.config.llmApiKey) {
      hilog.error(DOMAIN, TAG, '大模型密钥未配置');
      throw new Error('大模型密钥未配置');
    }

    const baseUrl = this.config.llmBaseUrl || 'https://dashscope.aliyuncs.com/compatible-mode/v1';
    const model = this.config.llmModel || 'qwen-plus';
    const url = `${baseUrl}/chat/completions`;

    hilog.info(DOMAIN, TAG, '开始调用大模型API, model: %{public}s, userQuery: %{public}s, POI数量: %{public}d',
      model, userQuery, pois.length);

    const systemPrompt = this.config.llmSystemPrompt ||
      '你是一个本地生活与旅行路线推荐助手，请结合给定的POI列表给出简洁、可执行的吃喝玩乐方案，并给出推荐理由与行程顺序。';

    // 构建POI信息文本
    const poiText = pois.map((poi, index) => {
      let text = `${index + 1}. ${poi.name}`;
      if (poi.address) {
        text += `（${poi.address}）`;
      }
      if (poi.distance !== undefined) {
        text += ` - 距离${poi.distance}米`;
      }
      return text;
    }).join('\n');

    const userContent = `用户问题：${userQuery}\n\n` +
      (context ? `上下文：${context}\n\n` : '') +
      `可选的POI列表：\n${poiText}\n\n` +
      `请根据用户问题，从上述POI中选择合适的推荐，并给出推荐理由和行程安排。如果用户问题涉及路线规划，请提供时间安排。`;

    const messages: LlmChatMessage[] = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userContent },
    ];

    hilog.debug(DOMAIN, TAG, '大模型请求消息长度: system=%{public}d, user=%{public}d',
      systemPrompt.length, userContent.length);

    try {
      // 大模型API通常需要更长的超时时间，使用配置的超时时间或默认60秒
      const llmTimeout = this.config.networkTimeout || 60000;
      
      // 开启联网功能，优先使用配置，默认开启
      const enableSearch = this.config.llmEnableSearch !== false; // 默认true，除非明确设置为false
      
      const requestBody = {
        model: model,
        messages: messages,
        temperature: 0.7,
        max_tokens: 1500, // 减少token数量以加快响应
        enable_search: enableSearch, // 开启联网功能
      } as LlmChatRequest;

      hilog.info(DOMAIN, TAG,
        `大模型请求参数: model=%{public}s, temperature=%{public}f, max_tokens=%{public}d, enable_search=%{public}s（网页搜索${enableSearch ? '已开启' : '未开启'}）, timeout=%{public}dms`,
        model, 0.7, 1500, enableSearch ? 'true' : 'false', llmTimeout);

      const startTime = Date.now();
      const response = await httpPost<LlmChatResponse>(
        url,
        requestBody,
        {
          headers: {
            'Authorization': `Bearer ${this.config.llmApiKey}`,
            'Content-Type': 'application/json',
          },
          timeout: llmTimeout,
        }
      );
      const duration = Date.now() - startTime;

      hilog.info(DOMAIN, TAG, '大模型API响应成功, 耗时: %{public}dms, statusCode: %{public}d',
        duration, response.statusCode);

      if (response.data.error) {
        hilog.error(DOMAIN, TAG, '大模型API返回错误: %{public}s, type: %{public}s',
          response.data.error.message, response.data.error.type || 'unknown');
        throw new Error(`大模型API错误: ${response.data.error.message}`);
      }

      const content = response.data.choices?.[0]?.message?.content;
      if (!content) {
        hilog.error(DOMAIN, TAG, '大模型返回内容为空');
        throw new Error('大模型返回内容为空');
      }

      hilog.info(DOMAIN, TAG, '大模型返回内容长度: %{public}d字符', content.length);
      hilog.debug(DOMAIN, TAG, '大模型返回内容预览: %{public}s', content.substring(0, 100));
      return content;
    } catch (error) {
      const httpErr = error as HttpError;
      hilog.error(DOMAIN, TAG, '大模型调用失败: %{public}s, code: %{public}s',
        httpErr.message || '网络错误', String(httpErr.code || 'unknown'));
      throw new Error(`大模型调用失败: ${httpErr.message || '网络错误'}`);
    }
  }
}

