import http from '@ohos.net.http';
import { BusinessError } from '@kit.BasicServicesKit';

export interface HttpError {
  code: number | string;
  message: string;
}

export interface HttpResult<T> {
  data: T;
  statusCode: number;
  headers: Record<string, string>;
}

interface RequestOptions {
  params?: Record<string, string | number | undefined>;
  headers?: Record<string, string>;
  timeout?: number;
}

function buildQuery(params?: Record<string, string | number | undefined>): string {
  if (!params) {
    return '';
  }
  const query = Object.entries(params)
    .filter(([, value]) => value !== undefined && value !== null && value !== '')
    .map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`)
    .join('&');
  return query ? `?${query}` : '';
}

function parseBody(result: unknown): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    const uint8Array = new Uint8Array(result);
    return uint8ArrayToString(uint8Array);
  }
  if (ArrayBuffer.isView(result)) {
    return uint8ArrayToString(result as Uint8Array);
  }
  return '';
}

function uint8ArrayToString(data: Uint8Array): string {
  // 手动转换Uint8Array到字符串
  let result = '';
  for (let i = 0; i < data.length; i++) {
    result += String.fromCharCode(data[i]);
  }
  return result;
}

function normalizeError(err: BusinessError | Error | unknown, fallback: string): HttpError {
  if (err && typeof err === 'object' && 'code' in (err as Record<string, unknown>)) {
    const business = err as BusinessError;
    return { code: business.code ?? -1, message: business.message ?? fallback };
  }
  const e = err as Error;
  return { code: -1, message: e?.message ?? fallback };
}

export async function httpGet<T>(url: string, options: RequestOptions = {}): Promise<HttpResult<T>> {
  const fullUrl = `${url}${buildQuery(options.params)}`;
  const httpRequest = http.createHttp();
  return new Promise<HttpResult<T>>((resolve, reject) => {
    httpRequest.request(fullUrl, {
      method: http.RequestMethod.GET,
      header: options.headers ?? {},
      connectTimeout: options.timeout ?? 10000,
      readTimeout: options.timeout ?? 10000,
    }, (err, data) => {
      httpRequest.destroy();
      if (err) {
        reject(normalizeError(err, '网络请求失败'));
        return;
      }
      try {
        const bodyText = parseBody(data.result);
        const parsed = bodyText ? JSON.parse(bodyText) as T : ({} as T);
        const headers: Record<string, string> = {};
        if (data.header && typeof data.header === 'object') {
          const headerObj = data.header as Record<string, unknown>;
          for (const key in headerObj) {
            if (typeof headerObj[key] === 'string') {
              headers[key] = headerObj[key] as string;
            }
          }
        }
        resolve({
          data: parsed,
          statusCode: data.responseCode ?? 0,
          headers: headers,
        });
      } catch (parseError) {
        reject(normalizeError(parseError, '响应解析失败'));
      }
    });
  });
}

export async function httpPost<T>(url: string, body: unknown, options: RequestOptions = {}): Promise<HttpResult<T>> {
  const httpRequest = http.createHttp();
  return new Promise<HttpResult<T>>((resolve, reject) => {
    httpRequest.request(url, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json',
        ...(options.headers ?? {}),
      },
      extraData: JSON.stringify(body ?? {}),
      connectTimeout: options.timeout ?? 10000,
      readTimeout: options.timeout ?? 10000,
    }, (err, data) => {
      httpRequest.destroy();
      if (err) {
        reject(normalizeError(err, '网络请求失败'));
        return;
      }
      try {
        const bodyText = parseBody(data.result);
        const parsed = bodyText ? JSON.parse(bodyText) as T : ({} as T);
        const headers: Record<string, string> = {};
        if (data.header && typeof data.header === 'object') {
          const headerObj = data.header as Record<string, unknown>;
          for (const key in headerObj) {
            if (typeof headerObj[key] === 'string') {
              headers[key] = headerObj[key] as string;
            }
          }
        }
        resolve({
          data: parsed,
          statusCode: data.responseCode ?? 0,
          headers: headers,
        });
      } catch (parseError) {
        reject(normalizeError(parseError, '响应解析失败'));
      }
    });
  });
}
