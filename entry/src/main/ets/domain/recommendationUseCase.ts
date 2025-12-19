import { AmapService } from '../services/amapService';
import { LlmService } from '../services/llmService';
import type { PoiItem, RecommendationResult, RecommendationRequest, WeatherInfo, WeatherForecast } from '../services/types';
import type { AppConfig } from '../common/config';

/**
 * 推荐用例：组合高德地图POI搜索和大模型推荐生成
 */
export class RecommendationUseCase {
  private amapService: AmapService;
  private llmService: LlmService;
  private config: AppConfig;

  constructor(config: AppConfig) {
    this.config = config;
    this.amapService = new AmapService(config);
    this.llmService = new LlmService(config);
  }

  /**
   * 获取推荐结果
   */
  async getRecommendations(request: RecommendationRequest): Promise<RecommendationResult> {
    try {
      // 1. 优先使用请求中的目的地城市，如果没有则从查询中解析
      const targetCity = request.destination || request.city || this.config.defaultCity || '北京';
      
      // 2. 解析用户查询，提取关键词（使用目标城市）
      const { keywords, city } = this.parseQuery(request.query, targetCity);
      
      // 确保使用正确的目标城市（优先使用request中的destination）
      const searchCity = request.destination || city || targetCity;

      // 3. 调用高德地图搜索POI（使用目标城市）
      let pois: PoiItem[] = [];
      if (!this.config.mockMode && this.config.amapKey) {
        try {
          // 使用更具体的旅游相关关键词，优先搜索景点
          let searchKeywords = keywords;
          if (!searchKeywords || searchKeywords === '景点 旅游') {
            // 如果没有提取到关键词，使用多个旅游相关关键词组合搜索
            searchKeywords = '景点|旅游景点|名胜古迹|景区|公园|博物馆|纪念馆';
          } else if (!searchKeywords.includes('景点') && !searchKeywords.includes('旅游')) {
            // 如果关键词不包含景点相关词，则添加景点关键词
            searchKeywords = `${searchKeywords}|景点|旅游景点`;
          }
          pois = await this.amapService.searchPoi(searchKeywords, searchCity);
          
          // 如果第一次搜索结果太少，尝试使用更通用的关键词
          if (pois.length < 5) {
            const fallbackPois = await this.amapService.searchPoi('景点', searchCity);
            // 合并结果，去重
            const existingNames = new Set(pois.map(p => p.name));
            const newPois = fallbackPois.filter(p => !existingNames.has(p.name));
            pois = [...pois, ...newPois].slice(0, 50); // 限制总数
          }
        } catch (error) {
          console.warn('高德API调用失败，使用空列表:', error);
          pois = [];
        }
      }

      // 3. 如果POI为空且不是mock模式，返回错误提示
      if (pois.length === 0 && !this.config.mockMode) {
        return {
          summary: '未找到相关地点，请尝试其他关键词或检查网络连接。',
          items: [],
          fromMock: false,
        };
      }

      // 4. 获取天气信息（如果配置了高德地图密钥）
      let weather: WeatherInfo | null = null;
      let weatherForecast: WeatherForecast[] | null = null;
      if (!this.config.mockMode && this.config.amapKey && searchCity) {
        try {
          // 先获取城市编码，然后复用给两个天气查询，避免重复查询
          const cityAdcode = await this.amapService.getCityAdcode(searchCity);
          weather = await this.amapService.getWeather(searchCity, cityAdcode);
          weatherForecast = await this.amapService.getWeatherForecast(searchCity, cityAdcode);
        } catch (error) {
          console.warn('天气查询失败，继续生成推荐:', error);
        }
      }

      // 5. 调用大模型生成推荐内容
      let summary = '';
      if (!this.config.mockMode && this.config.llmApiKey) {
        try {
          // 构建包含目的地信息和天气的上下文
          let context = '';
          if (request.destination) {
            context += `目的地: ${request.destination}`;
          }
          if (request.departure) {
            context += context ? `, 出发地: ${request.departure}` : `出发地: ${request.departure}`;
          }
          if (request.travelDate) {
            context += context ? `, 出行日期: ${request.travelDate}` : `出行日期: ${request.travelDate}`;
          }
          if (request.location) {
            context += context ? `, 当前位置: ${request.location}` : `当前位置: ${request.location}`;
          }
          
          // 添加天气信息到上下文
          if (weather) {
            context += context ? `, 当前天气: ${weather.weather}, 温度: ${weather.temperature}°C` : 
              `当前天气: ${weather.weather}, 温度: ${weather.temperature}°C`;
            if (weather.winddirection && weather.windpower) {
              context += `, 风向: ${weather.winddirection}, 风力: ${weather.windpower}`;
            }
            if (weather.humidity) {
              context += `, 湿度: ${weather.humidity}%`;
            }
          }
          
          // 添加天气预报到上下文
          if (weatherForecast && weatherForecast.length > 0) {
            const forecastText = weatherForecast.map(f => 
              `${f.date}: 白天${f.dayweather} ${f.daytemp}°C, 夜间${f.nightweather} ${f.nighttemp}°C`
            ).join('; ');
            context += context ? `, 未来天气: ${forecastText}` : `未来天气: ${forecastText}`;
          }
          
          summary = await this.llmService.generateRecommendation(
            request.query,
            pois,
            context || undefined
          );
        } catch (error) {
          const err = error as Error;
          console.warn('大模型调用失败，使用默认摘要:', err);
          // 如果是超时错误，在摘要中提示用户
          if (err.message.includes('Timeout') || err.message.includes('超时')) {
            summary = this.generateDefaultSummary(pois, request.query) + 
              '\n\n（注：AI推荐生成超时，已显示基础推荐列表）';
          } else {
            summary = this.generateDefaultSummary(pois, request.query);
          }
        }
      } else {
        summary = this.generateDefaultSummary(pois, request.query);
      }

      return {
        summary,
        items: pois,
        fromMock: this.config.mockMode || false,
        weather: weather || undefined,
        weatherForecast: weatherForecast || undefined,
      };
    } catch (error) {
      const err = error as Error;
      return {
        summary: `获取推荐失败: ${err.message}`,
        items: [],
        fromMock: false,
      };
    }
  }

  /**
   * 解析用户查询，提取关键词和城市
   */
  private parseQuery(query: string, defaultCity?: string): { keywords: string; city: string } {
    // 优先使用传入的默认城市（应该是目的地）
    let city = defaultCity || this.config.defaultCity || '北京';
    let keywords = query.trim();

    // 如果已经提供了defaultCity，就不从查询中提取城市，直接使用
    // 如果没有提供defaultCity，才尝试从查询中提取目的地城市
    if (!defaultCity) {
      // 先提取出发地信息，避免误提取
      const departureMatch = query.match(/从([^，,]+)出发/);
      const departureCity = departureMatch ? departureMatch[1].trim() : '';
      
      // 尝试从查询中提取目的地城市（排除出发地）
      const cityPatterns = [
        /(?:我想去|去|在|到|玩)([^玩天日出发，,]+?)(?:玩|旅游|一日游|两日游|三日游|出发)/,
        /([^今明后出发，,]+?)(?:一日游|两日游|三日游)/,
      ];

      for (const pattern of cityPatterns) {
        const match = query.match(pattern);
        if (match && match[1]) {
          const extractedCity = match[1].trim();
          // 排除出发地和无效城市名
          if (extractedCity.length <= 4 && 
              extractedCity !== departureCity &&
              !extractedCity.includes('出发') && 
              !extractedCity.includes('从')) {
            city = extractedCity;
            keywords = query.replace(new RegExp(`(?:我想去|去|在|到|玩)?${extractedCity}(?:玩|旅游|一日游|两日游|三日游)?`), '').trim();
            break;
          }
        }
      }
    }

    // 清理关键词，移除出发地信息
    keywords = keywords.replace(/从[^，,]+出发/g, '').trim();
    keywords = keywords.replace(/，从[^，,]+出发/g, '').trim();
    keywords = keywords.replace(/我想去/g, '').trim();

    // 如果没有提取到关键词，使用通用搜索词
    if (!keywords || keywords.length < 2) {
      keywords = '景点 旅游';
    }

    // 处理常见查询模式
    if (keywords.includes('吃什么') || keywords.includes('餐厅') || keywords.includes('美食')) {
      keywords = '餐厅 美食';
    } else if (keywords.includes('玩什么') || keywords.includes('景点') || keywords.includes('旅游')) {
      keywords = '景点 旅游';
    } else if (keywords.includes('咖啡') || keywords.includes('咖啡店')) {
      keywords = '咖啡店';
    }

    return { keywords, city };
  }

  /**
   * 生成默认摘要（当LLM不可用时）
   */
  private generateDefaultSummary(pois: PoiItem[], query: string): string {
    if (pois.length === 0) {
      return `根据您的查询"${query}"，暂未找到相关推荐。`;
    }

    const items = pois.slice(0, 5).map((poi, index) => {
      let text = `${index + 1}. ${poi.name}`;
      if (poi.address) {
        text += `（${poi.address}）`;
      }
      if (poi.distance !== undefined) {
        text += ` - 距离${poi.distance}米`;
      }
      return text;
    }).join('\n');

    return `为您找到以下推荐：\n\n${items}\n\n${pois.length > 5 ? `还有${pois.length - 5}个结果未显示。` : ''}`;
  }
}

