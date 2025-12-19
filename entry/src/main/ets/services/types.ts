export interface PoiItem {
  name: string;
  address?: string;
  location?: string;
  city?: string;
  distance?: number;
  score?: number;
  tel?: string;
  image?: string; // POI图片URL
}

export interface WeatherInfo {
  city: string;
  adcode?: string;
  weather: string; // 天气现象
  temperature: string; // 温度
  winddirection?: string; // 风向
  windpower?: string; // 风力
  humidity?: string; // 湿度
  reporttime?: string; // 数据发布时间
}

export interface WeatherForecast {
  date: string; // 日期
  week?: string; // 星期
  dayweather: string; // 白天天气
  nightweather: string; // 夜间天气
  daytemp: string; // 白天温度
  nighttemp: string; // 夜间温度
  daywind?: string; // 白天风向
  nightwind?: string; // 夜间风向
  daypower?: string; // 白天风力
  nightpower?: string; // 夜间风力
}

export interface RecommendationResult {
  summary: string;
  items: PoiItem[];
  fromMock?: boolean;
  weather?: WeatherInfo; // 实况天气
  weatherForecast?: WeatherForecast[]; // 天气预报
}

export interface RecommendationRequest {
  query: string;
  city?: string;
  location?: string;
  travelDate?: string;
  destination?: string;
  departure?: string;
}

