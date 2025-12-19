import http from '@ohos.net.http';

export interface HttpError extends Error {
  status?: number;
  code?: number;
}

export interface HttpResponse<T> {
  data: T;
  status: number;
}

function buildQuery(params?: Record<string, string | number | undefined>): string {
  if (!params) {
    return '';
  }
  const entries = Object.entries(params).filter(([, v]) => v !== undefined && v !== null);
  if (!entries.length) {
    return '';
  }
  const query = entries.map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`).join('&');
  return `?${query}`;
}

export async function httpGet<T>(url: string, params?: Record<string, string | number | undefined>, timeoutMs: number = 8000): Promise<HttpResponse<T>> {
  const client = http.createHttp();
  try {
    const resp = await client.request(`${url}${buildQuery(params)}`, {
      method: http.RequestMethod.GET,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs,
      usingCache: false,
      expectDataType: http.HttpDataType.STRING
    });
    const status = resp.responseCode;
    if (status >= 200 && status < 300) {
      const data = resp.result ? JSON.parse(resp.result as string) as T : ({} as unknown as T);
      return { data, status };
    }
    const err: HttpError = new Error(`HTTP ${status}`);
    err.status = status;
    throw err;
  } finally {
    client.destroy();
  }
}

export async function httpPost<T>(url: string, body: any, headers: Record<string, string>, timeoutMs: number = 8000): Promise<HttpResponse<T>> {
  const client = http.createHttp();
  try {
    const resp = await client.request(url, {
      method: http.RequestMethod.POST,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs,
      usingCache: false,
      expectDataType: http.HttpDataType.STRING,
      header: {
        'Content-Type': 'application/json',
        ...headers
      },
      extraData: JSON.stringify(body)
    });
    const status = resp.responseCode;
    if (status >= 200 && status < 300) {
      const data = resp.result ? JSON.parse(resp.result as string) as T : ({} as unknown as T);
      return { data, status };
    }
    const err: HttpError = new Error(`HTTP ${status}`);
    err.status = status;
    throw err;
  } finally {
    client.destroy();
  }
}

