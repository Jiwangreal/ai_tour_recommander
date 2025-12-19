export type PoiRecommendation = {
  name: string;
  address?: string;
  distance?: number;
  category?: string;
  score?: number;
};

export type RecommendationResult = {
  summary: string;
  items: PoiRecommendation[];
  source: 'live' | 'mock';
};

