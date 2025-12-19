import { RecommendationUseCase } from '../domain/recommendationUseCase';
import { generateMockRecommendation } from '../domain/mockData';
import { loadConfig, missingCriticalKeys, type AppConfig } from '../common/config';
import { RecommendationRequest, type RecommendationResult, type PoiItem } from '../services/types';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';

@Entry
@Component
struct Index {
  @State query: string = '';
  @State loading: boolean = false;
  @State result: RecommendationResult | null = null;
  @State error: string = '';
  @State config: AppConfig | null = null;
  @State configError: string = '';

  private context?: common.UIAbilityContext;
  private useCase: RecommendationUseCase | null = null;

  aboutToAppear() {
    this.context = getContext(this) as common.UIAbilityContext;
    this.loadConfiguration();
  }

  async loadConfiguration() {
    if (!this.context) {
      this.configError = '无法获取应用上下文';
      return;
    }

    try {
      const configResult = await loadConfig(this.context);
      this.config = configResult.config;
      
      if (configResult.source === 'fallback') {
        this.configError = configResult.message || '使用默认配置（Mock模式）';
      }

      const missing = missingCriticalKeys(this.config);
      if (missing) {
        this.configError = missing;
      } else {
        this.useCase = new RecommendationUseCase(this.config);
      }
    } catch (error) {
      const err = error as Error;
      this.configError = `配置加载失败: ${err.message}`;
    }
  }

  async handleSearch() {
    if (!this.query.trim()) {
      promptAction.showToast({
        message: '请输入查询内容',
        duration: 2000,
      });
      return;
    }

    this.loading = true;
    this.error = '';
    this.result = null;

    try {
      let recommendation: RecommendationResult;

      if (this.config?.mockMode || !this.useCase) {
        // 使用Mock数据
        recommendation = generateMockRecommendation(this.query);
      } else {
        // 调用真实API
        const request: RecommendationRequest = {
          query: this.query,
          city: this.config?.defaultCity,
        };
        recommendation = await this.useCase.getRecommendations(request);
      }

      this.result = recommendation;
    } catch (error) {
      const err = error as Error;
      this.error = err.message;
      promptAction.showToast({
        message: `查询失败: ${err.message}`,
        duration: 3000,
      });
    } finally {
      this.loading = false;
    }
  }

  handleQuickQuery(text: string) {
    this.query = text;
    this.handleSearch();
  }

  build() {
    Column() {
      // 顶部标题和配置提示
      Column() {
        Text('智能旅行推荐助手')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 20, bottom: 10 });

        if (this.configError) {
          Text(this.configError)
            .fontSize(12)
            .fontColor('#FF6B6B')
            .margin({ bottom: 10 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis });
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      // 搜索输入框
      Row() {
        TextInput({ placeholder: '例如：今天吃什么？我想去北京玩1天' })
          .layoutWeight(1)
          .height(48)
          .fontSize(16)
          .onChange((value: string) => {
            this.query = value;
          })
          .onSubmit(() => {
            this.handleSearch();
          })

        Button('搜索')
          .type(ButtonType.Capsule)
          .height(48)
          .margin({ left: 8 })
          .onClick(() => {
            this.handleSearch();
          })
          .enabled(!this.loading)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })

      // 快捷查询按钮
      Column() {
        Text('快捷查询')
          .fontSize(14)
          .fontColor('#666666')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 8 })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          Button('今天吃什么？')
            .type(ButtonType.Normal)
            .fontSize(14)
            .margin(4)
            .onClick(() => {
              this.handleQuickQuery('今天吃什么？');
            })

          Button('北京一日游')
            .type(ButtonType.Normal)
            .fontSize(14)
            .margin(4)
            .onClick(() => {
              this.handleQuickQuery('我想去北京玩 1 天');
            })

          Button('附近咖啡店')
            .type(ButtonType.Normal)
            .fontSize(14)
            .margin(4)
            .onClick(() => {
              this.handleQuickQuery('附近有什么评价高、人不多的小众咖啡店？');
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 10 })
      .alignItems(HorizontalAlign.Start)

      // 加载状态
      if (this.loading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#007DFF')
          Text('正在搜索推荐...')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 12 })
        }
        .width('100%')
        .height(200)
        .justifyContent(FlexAlign.Center)
      }

      // 错误提示
      if (this.error && !this.loading) {
        Column() {
          Text('❌')
            .fontSize(32)
            .margin({ bottom: 8 })
          Text(this.error)
            .fontSize(14)
            .fontColor('#FF6B6B')
            .textAlign(TextAlign.Center)
            .padding({ left: 16, right: 16 })
        }
        .width('100%')
        .padding({ top: 40, bottom: 40 })
        .justifyContent(FlexAlign.Center)
      }

      // 结果展示
      if (this.result && !this.loading) {
        Scroll() {
          Column() {
            // 推荐摘要
            if (this.result.summary) {
              Column() {
                Text('💡 智能推荐')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 12 })

                Text(this.result.summary)
                  .fontSize(15)
                  .lineHeight(24)
                  .textAlign(TextAlign.Start)
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .margin({ bottom: 16 })
            }

            // POI列表
            if (this.result.items && this.result.items.length > 0) {
              Column() {
                Text('📍 推荐地点')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 12 })

                ForEach(this.result.items, (item: PoiItem, index: number) => {
                  this.buildPoiItem(item, index);
                })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
            }

            // Mock模式提示
            if (this.result.fromMock) {
              Text('（当前为演示模式，使用Mock数据）')
                .fontSize(12)
                .fontColor('#999999')
                .margin({ top: 16 })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 20 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  buildPoiItem(item: PoiItem, index: number) {
    Column() {
      Row() {
        Column() {
          Text(`${index + 1}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        .width(32)
        .height(32)
        .backgroundColor('#007DFF')
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)

        Column() {
          Text(item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 4 })

          if (item.address) {
            Text(item.address)
              .fontSize(13)
              .fontColor('#666666')
              .alignSelf(ItemAlign.Start)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }

          Row() {
            if (item.score !== undefined) {
              Text(`⭐ ${item.score}`)
                .fontSize(12)
                .fontColor('#FF9500')
            }
            if (item.distance !== undefined) {
              Text(`距离 ${item.distance}米`)
                .fontSize(12)
                .fontColor('#999999')
                .margin({ left: item.score !== undefined ? 12 : 0 })
            }
            if (item.tel) {
              Text(`📞 ${item.tel}`)
                .fontSize(12)
                .fontColor('#999999')
                .margin({ left: 12 })
            }
          }
          .width('100%')
          .margin({ top: 4 })
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ bottom: 8 })
    .shadow({
      radius: 4,
      color: '#1F000000',
      offsetX: 0,
      offsetY: 2,
    })
  }
}
