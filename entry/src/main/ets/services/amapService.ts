import { httpGet, HttpError } from '../common/httpClient';
import type { AppConfig } from '../common/config';
import type { PoiItem, WeatherInfo, WeatherForecast } from './types';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'AmapService';

export interface AmapPoiSearchResponse {
  status: string;
  count: string;
  info: string;
  infocode: string;
  pois?: Array<{
    id: string;
    name: string;
    type: string;
    typecode: string;
    address: string;
    location: string;
    tel?: string;
    distance?: string;
    business_area?: string;
    photos?: Array<{
      title?: string;
      url?: string;
    }>;
  }>;
}

export interface AmapGeocodeResponse {
  status: string;
  count: string;
  info: string;
  infocode: string;
  geocodes?: Array<{
    formatted_address: string;
    country: string;
    province: string;
    city: string;
    district: string;
    location: string;
    adcode?: string;
  }>;
}

export interface AmapWeatherResponse {
  status: string;
  count: string;
  info: string;
  infocode: string;
  lives?: Array<{
    province: string;
    city: string;
    adcode: string;
    weather: string;
    temperature: string;
    winddirection: string;
    windpower: string;
    humidity: string;
    reporttime: string;
  }>;
  forecasts?: Array<{
    city: string;
    adcode: string;
    province: string;
    reporttime: string;
    casts: Array<{
      date: string;
      week: string;
      dayweather: string;
      nightweather: string;
      daytemp: string;
      nighttemp: string;
      daywind: string;
      nightwind: string;
      daypower: string;
      nightpower: string;
    }>;
  }>;
}

/**
 * 高德地图POI搜索服务
 */
export class AmapService {
  private config: AppConfig;

  constructor(config: AppConfig) {
    this.config = config;
  }

  /**
   * 根据关键词和城市搜索POI
   */
  async searchPoi(keywords: string, city?: string): Promise<PoiItem[]> {
    if (!this.config.amapKey) {
      hilog.error(DOMAIN, TAG, '高德地图密钥未配置');
      throw new Error('高德地图密钥未配置');
    }

    const baseUrl = this.config.amapBaseUrl || 'https://restapi.amap.com/v3';
    const url = `${baseUrl}/place/text`;
    const searchCity = city || this.config.defaultCity || '北京';

    hilog.info(DOMAIN, TAG, '开始调用高德地图POI搜索API, keywords: %{public}s, city: %{public}s', keywords, searchCity);

    try {
      const requestParams = {
        key: this.config.amapKey,
        keywords: keywords,
        city: searchCity,
        output: 'JSON',
        offset: 50, // 增加返回数量，获取更多POI
        page: 1,
        extensions: 'all',
      };
      
      hilog.debug(DOMAIN, TAG, '高德地图请求参数: %{public}s', JSON.stringify(requestParams));

      const startTime = Date.now();
      const response = await httpGet<AmapPoiSearchResponse>(url, {
        params: requestParams,
        timeout: this.config.networkTimeout || 12000,
      });
      const duration = Date.now() - startTime;

      hilog.info(DOMAIN, TAG, '高德地图API响应成功, 耗时: %{public}dms, status: %{public}s, count: %{public}s',
        duration, response.data.status, response.data.count);

      if (response.data.status !== '1') {
        hilog.error(DOMAIN, TAG, '高德API返回错误, status: %{public}s, info: %{public}s, infocode: %{public}s',
          response.data.status, response.data.info, response.data.infocode);
        throw new Error(`高德API错误: ${response.data.info || '未知错误'}`);
      }

      const pois = response.data.pois || [];
      hilog.info(DOMAIN, TAG, '高德地图返回POI数量: %{public}d', pois.length);

      const result = pois.map((poi) => {
        // 提取POI图片（优先使用第一张图片）
        let imageUrl: string | undefined = undefined;
        if (poi.photos && poi.photos.length > 0 && poi.photos[0].url) {
          imageUrl = poi.photos[0].url;
        }
        
        return {
          name: poi.name,
          address: poi.address || poi.business_area || '',
          location: poi.location,
          city: searchCity,
          distance: poi.distance ? Number(poi.distance) : undefined,
          tel: poi.tel,
          image: imageUrl,
        } as PoiItem;
      });

      hilog.debug(DOMAIN, TAG, 'POI搜索结果: %{public}s', JSON.stringify(result.map(p => ({ name: p.name, address: p.address }))));
      return result;
    } catch (error) {
      const httpErr = error as HttpError;
      hilog.error(DOMAIN, TAG, '高德地图POI搜索失败: %{public}s, code: %{public}s',
        httpErr.message || '网络错误', String(httpErr.code || 'unknown'));
      throw new Error(`POI搜索失败: ${httpErr.message || '网络错误'}`);
    }
  }

  /**
   * 地理编码：将地址转换为坐标
   */
  async geocode(address: string, city?: string): Promise<{ location: string; address: string } | null> {
    if (!this.config.amapKey) {
      hilog.error(DOMAIN, TAG, '高德地图密钥未配置');
      throw new Error('高德地图密钥未配置');
    }

    const baseUrl = this.config.amapBaseUrl || 'https://restapi.amap.com/v3';
    const url = `${baseUrl}/geocode/geo`;
    const searchCity = city || this.config.defaultCity || '北京';

    hilog.info(DOMAIN, TAG, '开始调用高德地图地理编码API, address: %{public}s, city: %{public}s', address, searchCity);

    try {
      const requestParams = {
        key: this.config.amapKey,
        address: address,
        city: searchCity,
        output: 'JSON',
      };

      const startTime = Date.now();
      const response = await httpGet<AmapGeocodeResponse>(url, {
        params: requestParams,
        timeout: this.config.networkTimeout || 12000,
      });
      const duration = Date.now() - startTime;

      hilog.info(DOMAIN, TAG, '高德地图地理编码响应, 耗时: %{public}dms, status: %{public}s',
        duration, response.data.status);

      if (response.data.status !== '1' || !response.data.geocodes || response.data.geocodes.length === 0) {
        hilog.warn(DOMAIN, TAG, '高德地图地理编码未找到结果');
        return null;
      }

      const geocode = response.data.geocodes[0];
      hilog.info(DOMAIN, TAG, '地理编码成功, location: %{public}s, address: %{public}s',
        geocode.location, geocode.formatted_address);
      return {
        location: geocode.location,
        address: geocode.formatted_address,
      };
    } catch (error) {
      const httpErr = error as HttpError;
      hilog.warn(DOMAIN, TAG, '地理编码失败: %{public}s, code: %{public}s',
        httpErr.message || '网络错误', String(httpErr.code || 'unknown'));
      return null;
    }
  }

  /**
   * 获取城市编码（adcode），用于天气查询
   */
  async getCityAdcode(cityName: string): Promise<string | null> {
    if (!this.config.amapKey) {
      hilog.error(DOMAIN, TAG, '高德地图密钥未配置');
      return null;
    }

    const baseUrl = this.config.amapBaseUrl || 'https://restapi.amap.com/v3';
    const url = `${baseUrl}/geocode/geo`;
    
    try {
      // 直接调用地理编码API，不传入city参数，避免编码问题
      const requestParams = {
        key: this.config.amapKey,
        address: cityName,
        output: 'JSON',
      };

      const response = await httpGet<AmapGeocodeResponse>(url, {
        params: requestParams,
        timeout: this.config.networkTimeout || 12000,
      });

      if (response.data.status === '1' && response.data.geocodes && response.data.geocodes.length > 0) {
        const adcode = response.data.geocodes[0].adcode;
        if (adcode) {
          hilog.info(DOMAIN, TAG, '获取城市编码成功, city: %{public}s, adcode: %{public}s', cityName, adcode);
          return adcode;
        }
      }
    } catch (error) {
      hilog.warn(DOMAIN, TAG, '获取城市编码失败: %{public}s', (error as Error).message);
    }

    // 如果地理编码失败，尝试直接使用城市名查询天气（高德API可能支持）
    hilog.warn(DOMAIN, TAG, '无法获取城市编码，将尝试使用城市名直接查询天气');
    return null;
  }

  /**
   * 获取实况天气
   * @param city 城市名称
   * @param adcode 可选的城市编码（如果已获取，可传入以避免重复查询）
   */
  async getWeather(city: string, adcode?: string | null): Promise<WeatherInfo | null> {
    if (!this.config.amapKey) {
      hilog.error(DOMAIN, TAG, '高德地图密钥未配置');
      return null;
    }

    const baseUrl = this.config.amapBaseUrl || 'https://restapi.amap.com/v3';
    const url = `${baseUrl}/weather/weatherInfo`;

    hilog.info(DOMAIN, TAG, '开始调用高德地图天气API（实况）, city: %{public}s', city);

    try {
      // 如果未提供adcode，则尝试获取城市编码
      let cityParam = city;
      let finalAdcode = adcode;
      if (!finalAdcode) {
        finalAdcode = await this.getCityAdcode(city);
      }
      if (finalAdcode) {
        cityParam = finalAdcode;
      }

      const requestParams = {
        key: this.config.amapKey,
        city: cityParam,
        extensions: 'base',
        output: 'JSON',
      };

      hilog.debug(DOMAIN, TAG, '高德天气请求参数: %{public}s', JSON.stringify(requestParams));

      const startTime = Date.now();
      const response = await httpGet<AmapWeatherResponse>(url, {
        params: requestParams,
        timeout: this.config.networkTimeout || 12000,
      });
      const duration = Date.now() - startTime;

      hilog.info(DOMAIN, TAG, '高德天气API响应, 耗时: %{public}dms, status: %{public}s',
        duration, response.data.status);

      if (response.data.status !== '1' || !response.data.lives || response.data.lives.length === 0) {
        hilog.warn(DOMAIN, TAG, '高德天气API未返回数据, status: %{public}s, info: %{public}s',
          response.data.status, response.data.info);
        return null;
      }

      const live = response.data.lives[0];
      const weatherInfo: WeatherInfo = {
        city: live.city,
        adcode: live.adcode,
        weather: live.weather,
        temperature: live.temperature,
        winddirection: live.winddirection,
        windpower: live.windpower,
        humidity: live.humidity,
        reporttime: live.reporttime,
      };

      hilog.info(DOMAIN, TAG, '获取天气成功, city: %{public}s, weather: %{public}s, temp: %{public}s°C',
        weatherInfo.city, weatherInfo.weather, weatherInfo.temperature);
      return weatherInfo;
    } catch (error) {
      const httpErr = error as HttpError;
      hilog.error(DOMAIN, TAG, '高德天气查询失败: %{public}s, code: %{public}s',
        httpErr.message || '网络错误', String(httpErr.code || 'unknown'));
      return null;
    }
  }

  /**
   * 获取天气预报（未来3天）
   * @param city 城市名称
   * @param adcode 可选的城市编码（如果已获取，可传入以避免重复查询）
   */
  async getWeatherForecast(city: string, adcode?: string | null): Promise<WeatherForecast[] | null> {
    if (!this.config.amapKey) {
      hilog.error(DOMAIN, TAG, '高德地图密钥未配置');
      return null;
    }

    const baseUrl = this.config.amapBaseUrl || 'https://restapi.amap.com/v3';
    const url = `${baseUrl}/weather/weatherInfo`;

    hilog.info(DOMAIN, TAG, '开始调用高德地图天气API（预报）, city: %{public}s', city);

    try {
      // 如果未提供adcode，则尝试获取城市编码
      let cityParam = city;
      let finalAdcode = adcode;
      if (!finalAdcode) {
        finalAdcode = await this.getCityAdcode(city);
      }
      if (finalAdcode) {
        cityParam = finalAdcode;
      }

      const requestParams = {
        key: this.config.amapKey,
        city: cityParam,
        extensions: 'all',
        output: 'JSON',
      };

      hilog.debug(DOMAIN, TAG, '高德天气预报请求参数: %{public}s', JSON.stringify(requestParams));

      const startTime = Date.now();
      const response = await httpGet<AmapWeatherResponse>(url, {
        params: requestParams,
        timeout: this.config.networkTimeout || 12000,
      });
      const duration = Date.now() - startTime;

      hilog.info(DOMAIN, TAG, '高德天气预报API响应, 耗时: %{public}dms, status: %{public}s',
        duration, response.data.status);

      if (response.data.status !== '1' || !response.data.forecasts || response.data.forecasts.length === 0) {
        hilog.warn(DOMAIN, TAG, '高德天气预报API未返回数据, status: %{public}s, info: %{public}s',
          response.data.status, response.data.info);
        return null;
      }

      const forecast = response.data.forecasts[0];
      const forecasts: WeatherForecast[] = forecast.casts.map((cast) => ({
        date: cast.date,
        week: cast.week,
        dayweather: cast.dayweather,
        nightweather: cast.nightweather,
        daytemp: cast.daytemp,
        nighttemp: cast.nighttemp,
        daywind: cast.daywind,
        nightwind: cast.nightwind,
        daypower: cast.daypower,
        nightpower: cast.nightpower,
      }));

      hilog.info(DOMAIN, TAG, '获取天气预报成功, city: %{public}s, 预报天数: %{public}d',
        forecast.city, forecasts.length);
      return forecasts;
    } catch (error) {
      const httpErr = error as HttpError;
      hilog.error(DOMAIN, TAG, '高德天气预报查询失败: %{public}s, code: %{public}s',
        httpErr.message || '网络错误', String(httpErr.code || 'unknown'));
      return null;
    }
  }
}

