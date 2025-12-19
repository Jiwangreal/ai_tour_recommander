import { RecommendationUseCase } from '../domain/recommendationUseCase';
import { generateMockRecommendation } from '../domain/mockData';
import { loadConfig, missingCriticalKeys, type AppConfig } from '../common/config';
import { RecommendationRequest, type RecommendationResult, type PoiItem } from '../services/types';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';

interface TravelFormData {
  departure: string;
  destination: string;
  travelDate: string;
  travelDays: string;
  companions: string;
  budget: string;
}

interface Interest {
  id: string;
  name: string;
  icon: string;
}

@Entry
@Component
struct TravelForm {
  @State departure: string = '';
  @State destination: string = '';
  @State travelDate: string = '';
  @State travelDays: string = '';
  @State companions: string = '2人 (情侣/朋友)';
  @State budget: string = '';
  @State loading: boolean = false;
  @State result: RecommendationResult | null = null;
  @State error: string = '';
  @State config: AppConfig | null = null;
  @State configError: string = '';
  @State holidayExpanded: boolean = false;
  @State selectedInterests: string[] = [];
  @State generateBudget: boolean = false;
  @State generateMapLink: boolean = true;
  @State queryWeather: boolean = true;
  @State routePlanning: boolean = false;
  @State showCityPicker: boolean = false;
  @State showDeparturePicker: boolean = false;
  @State showCompanionPicker: boolean = false;
  @State citySearchText: string = '';
  @State departureSearchText: string = '';
  @State destinationSuggestions: string[] = [];
  @State departureSuggestions: string[] = [];
  @State showDestinationSuggestions: boolean = false;
  @State showDepartureSuggestions: boolean = false;

  private context?: common.UIAbilityContext;
  private useCase: RecommendationUseCase | null = null;

  // 兴趣偏好选项
  private interests: Interest[] = [
    { id: 'food', name: '美食', icon: '🍜' },
    { id: 'nature', name: '自然风光', icon: '⛰️' },
    { id: 'citywalk', name: '城市漫步', icon: '🚶' },
    { id: 'family', name: '亲子', icon: '👨‍👩‍👧' },
    { id: 'adventure', name: '小众冒险', icon: '🎒' },
    { id: 'drive', name: '自驾', icon: '🚗' },
    { id: 'hiking', name: '徒步', icon: '🥾' },
    { id: 'climbing', name: '爬山', icon: '⛰️' },
    { id: 'shopping', name: '商场逛街', icon: '🛍️' },
  ];

  // 节假日选项
  private holidays: string[] = [
    '春节', '清明节', '劳动节', '端午节', '中秋节', '国庆节', '元旦'
  ];

  // 同行人数选项
  private companionOptions: string[] = [
    '1人 (独自)',
    '2人 (情侣/朋友)',
    '3人',
    '4人',
    '5+人 (团队)'
  ];

  // 城市列表（按字母排序）
  private cities: string[] = [
    '北京', '上海', '广州', '深圳', '杭州', '南京', '成都', '重庆', '武汉', '西安',
    '天津', '苏州', '长沙', '郑州', '东莞', '青岛', '沈阳', '宁波', '昆明', '大连',
    '厦门', '合肥', '佛山', '福州', '哈尔滨', '济南', '温州', '石家庄', '泉州', '长春',
    '贵阳', '常州', '珠海', '金华', '嘉兴', '台州', '惠州', '中山', '保定', '兰州',
    '潍坊', '临沂', '淄博', '济宁', '烟台', '泰安', '聊城', '威海', '枣庄', '德州',
    '滨州', '东营', '菏泽', '日照', '莱芜', '青岛', '潍坊', '临沂', '淄博', '济宁',
    '三亚', '海口', '桂林', '丽江', '大理', '西双版纳', '张家界', '九寨沟', '黄山', '庐山',
    '峨眉山', '泰山', '华山', '衡山', '恒山', '嵩山', '五台山', '普陀山', '武当山', '青城山',
    '拉萨', '乌鲁木齐', '呼和浩特', '银川', '西宁', '兰州', '昆明', '贵阳', '南宁', '海口',
    '香港', '澳门', '台北', '高雄', '台中', '台南', '新北', '桃园', '新竹', '基隆'
  ].sort((a, b) => {
    // 按拼音首字母排序
    return a.localeCompare(b, 'zh-CN');
  });

  // 按首字母分组城市
  private getCitiesByLetter(): Map<string, string[]> {
    const grouped = new Map<string, string[]>();
    for (const city of this.cities) {
      // 获取拼音首字母
      const firstLetter = this.getFirstLetter(city);
      if (!grouped.has(firstLetter)) {
        grouped.set(firstLetter, []);
      }
      grouped.get(firstLetter)?.push(city);
    }
    return grouped;
  }

  // 获取中文拼音首字母（简化版）
  private getFirstLetter(city: string): string {
    // 使用localeCompare获取排序键，然后取首字符
    // 简化实现：使用Unicode范围判断，或使用首字符的拼音首字母映射
    const firstChar = city.charAt(0);
    
    // 扩展的拼音首字母映射
    const pinyinMap: Record<string, string> = {
      '北': 'B', '上': 'S', '广': 'G', '深': 'S', '杭': 'H', '南': 'N', '成': 'C', '重': 'C',
      '武': 'W', '西': 'X', '天': 'T', '苏': 'S', '长': 'C', '郑': 'Z', '东': 'D', '青': 'Q',
      '沈': 'S', '宁': 'N', '昆': 'K', '大': 'D', '厦': 'X', '合': 'H', '佛': 'F', '福': 'F',
      '哈': 'H', '济': 'J', '温': 'W', '石': 'S', '泉': 'Q', '贵': 'G', '常': 'C',
      '珠': 'Z', '金': 'J', '嘉': 'J', '台': 'T', '惠': 'H', '中': 'Z', '保': 'B', '兰': 'L',
      '三': 'S', '海': 'H', '桂': 'G', '丽': 'L', '张': 'Z', '九': 'J', '黄': 'H', '庐': 'L',
      '峨': 'E', '华': 'H', '衡': 'H', '恒': 'H', '嵩': 'S', '五': 'W', '普': 'P',
      '拉': 'L', '乌': 'W', '呼': 'H', '银': 'Y', '香': 'X', '澳': 'A', '高': 'G',
      '新': 'X', '基': 'J', '潍': 'W', '临': 'L', '淄': 'Z', '烟': 'Y', '泰': 'T',
      '聊': 'L', '威': 'W', '枣': 'Z', '德': 'D', '滨': 'B', '营': 'Y', '菏': 'H',
      '日': 'R', '莱': 'L', '版': 'B', '家': 'J', '山': 'S', '眉': 'M', '城': 'C'
    };
    
    // 如果映射中有，直接返回
    if (pinyinMap[firstChar]) {
      return pinyinMap[firstChar];
    }
    
    // 如果是英文字母，直接返回大写
    if (/[A-Za-z]/.test(firstChar)) {
      return firstChar.toUpperCase();
    }
    
    // 默认返回首字符（用于未知字符）
    return firstChar;
  }

  // 获取过滤后的城市列表
  private getFilteredCities(): Map<string, string[]> {
    const grouped = this.getCitiesByLetter();
    if (!this.citySearchText.trim()) {
      return grouped;
    }
    const filtered = new Map<string, string[]>();
    const searchLower = this.citySearchText.toLowerCase();
    for (const entry of grouped.entries()) {
      const letter = entry[0];
      const cities = entry[1];
      const filteredCities = cities.filter(city => 
        city.includes(this.citySearchText) || 
        city.toLowerCase().includes(searchLower)
      );
      if (filteredCities.length > 0) {
        filtered.set(letter, filteredCities);
      }
    }
    return filtered;
  }

  // 获取过滤后的出发地城市列表
  private getFilteredDepartureCities(): Map<string, string[]> {
    const grouped = this.getCitiesByLetter();
    if (!this.departureSearchText.trim()) {
      return grouped;
    }
    const filtered = new Map<string, string[]>();
    const searchLower = this.departureSearchText.toLowerCase();
    for (const entry of grouped.entries()) {
      const letter = entry[0];
      const cities = entry[1];
      const filteredCities = cities.filter(city => 
        city.includes(this.departureSearchText) || 
        city.toLowerCase().includes(searchLower)
      );
      if (filteredCities.length > 0) {
        filtered.set(letter, filteredCities);
      }
    }
    return filtered;
  }

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

  toggleInterest(interestId: string) {
    const index = this.selectedInterests.indexOf(interestId);
    if (index > -1) {
      this.selectedInterests.splice(index, 1);
    } else {
      this.selectedInterests.push(interestId);
    }
  }

  async handleGenerate() {
    if (!this.destination.trim()) {
      promptAction.showToast({
        message: '请填写目的地',
        duration: 2000,
      });
      return;
    }

    this.loading = true;
    this.error = '';
    this.result = null;

    try {
      // 构建查询字符串
      let query = `我想去${this.destination}`;
      if (this.travelDays) {
        query += `玩${this.travelDays}天`;
      }
      if (this.departure) {
        query += `，从${this.departure}出发`;
      }
      if (this.selectedInterests.length > 0) {
        const interestNames = this.selectedInterests.map(id => {
          const interest = this.interests.find(i => i.id === id);
          return interest?.name || id;
        });
        query += `，喜欢${interestNames.join('、')}`;
      }
      if (this.companions) {
        query += `，${this.companions}`;
      }
      if (this.budget) {
        query += `，预算${this.budget}`;
      }

      let recommendation: RecommendationResult;

      if (this.config?.mockMode || !this.useCase) {
        recommendation = generateMockRecommendation(query);
      } else {
        const request: RecommendationRequest = {
          query: query,
          city: this.destination || this.config?.defaultCity,
          destination: this.destination,
          departure: this.departure,
          travelDate: this.travelDate,
        };
        recommendation = await this.useCase.getRecommendations(request);
      }

      this.result = recommendation;
    } catch (error) {
      const err = error as Error;
      this.error = err.message;
      promptAction.showToast({
        message: `生成失败: ${err.message}`,
        duration: 3000,
      });
    } finally {
      this.loading = false;
    }
  }

  build() {
    Scroll() {
      Column() {
        // 顶部标题
        Row() {
          Text('快速填写旅行需求')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1F1F1F')
          Text('✨')
            .fontSize(18)
            .margin({ left: 4 })
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding({ left: 16, right: 16, top: 20, bottom: 16 })

        // 节假日快捷选择卡片
        Column() {
          Row() {
            Column() {
              Row() {
                Text('⚡')
                  .fontSize(16)
                Text('节假日快捷选择')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1F1F1F')
                  .margin({ left: 4 })
              }
              Text('快速规划假期出游')
                .fontSize(12)
                .fontColor('#666666')
                .margin({ top: 4 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Button(this.holidayExpanded ? '收起' : '展开')
              .type(ButtonType.Normal)
              .fontSize(12)
              .height(28)
              .backgroundColor('#F5F5F5')
              .fontColor('#333333')
              .onClick(() => {
                this.holidayExpanded = !this.holidayExpanded;
              })
          }
          .width('100%')

          if (this.holidayExpanded) {
            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
              ForEach(this.holidays, (holiday: string) => {
                Button(holiday)
                  .type(ButtonType.Normal)
                  .fontSize(13)
                  .height(32)
                  .margin(4)
                  .backgroundColor('#FFFFFF')
                  .fontColor('#333333')
                  .border({
                    width: 1,
                    color: '#E0E0E0',
                    radius: 16
                  })
                  .onClick(() => {
                    // 可以设置默认日期等
                    promptAction.showToast({
                      message: `已选择${holiday}`,
                      duration: 1500,
                    });
                  })
              })
            }
            .width('100%')
            .margin({ top: 12 })
          }
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .margin({ left: 16, right: 16, bottom: 16 })
        .shadow({
          radius: 4,
          color: '#1F000000',
          offsetX: 0,
          offsetY: 2,
        })

        // 表单输入区域
        Column() {
          // 出发地
          this.buildCityInputItem('📍', '出发地', '选择出发城市或输入自定义地点', this.departure, false, 'departure')

          // 目的地（必填）
          this.buildCityInputItem('✈️', '目的地*', '选择目的地或输入自定义地点', this.destination, true, 'destination')

          // 出行日期
          this.buildFormItem('📅', '出行日期', '输入日期，如：2025-12-15 至 2025-12-20', this.travelDate, (value: string) => {
            this.travelDate = value;
          })

          // 旅行天数
          this.buildFormItem('📅', '旅行天数', '选择天数', this.travelDays, (value: string) => {
            this.travelDays = value;
          })

          // 同行人数
          this.buildCompanionPickerItem('👥', '同行人数', this.companions)

          // 预算范围
          this.buildFormItem('💰', '预算范围 (可选)', '如: 3000-5000元', this.budget, (value: string) => {
            this.budget = value;
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .alignItems(HorizontalAlign.Start)

        // 兴趣偏好
        Column() {
          Text('兴趣偏好')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F1F1F')
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 12 })

          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.interests, (interest: Interest) => {
              Button(`${interest.icon} ${interest.name}`)
                .type(ButtonType.Normal)
                .fontSize(13)
                .height(36)
                .margin(4)
                .backgroundColor(this.selectedInterests.includes(interest.id) ? '#007DFF' : '#FFFFFF')
                .fontColor(this.selectedInterests.includes(interest.id) ? '#FFFFFF' : '#333333')
                .border({
                  width: 1,
                  color: this.selectedInterests.includes(interest.id) ? '#007DFF' : '#E0E0E0',
                  radius: 18
                })
                .onClick(() => {
                  this.toggleInterest(interest.id);
                })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 24, bottom: 16 })
        .alignItems(HorizontalAlign.Start)

        // 可选功能
        Column() {
          Text('可选功能')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F1F1F')
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 12 })

          this.buildCheckbox('💰', '生成预算明细', this.generateBudget, (value: boolean) => {
            this.generateBudget = value;
          })
          this.buildCheckbox('🗺️', '生成地图链接', this.generateMapLink, (value: boolean) => {
            this.generateMapLink = value;
          })
          this.buildCheckbox('☀️', '查询天气信息', this.queryWeather, (value: boolean) => {
            this.queryWeather = value;
          })
          this.buildCheckbox('🚗', '路线规划推荐', this.routePlanning, (value: boolean) => {
            this.routePlanning = value;
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        .alignItems(HorizontalAlign.Start)

        // 提示文字
        Text('填写目的地后点击生成')
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 8, bottom: 16 })

        // 生成按钮
        Button() {
          Row() {
            Text('✨')
              .fontSize(16)
            Text('免费生成行程')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ left: 4 })
          }
        }
        .type(ButtonType.Capsule)
        .width('90%')
        .height(48)
        .backgroundColor('#007DFF')
        .enabled(!this.loading && !!this.destination.trim())
        .onClick(() => {
          this.handleGenerate();
        })
        .margin({ bottom: 20 })

        // 加载状态
        if (this.loading) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .color('#007DFF')
            Text('正在生成行程...')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ top: 12 })
          }
          .width('100%')
          .padding({ top: 20, bottom: 20 })
        }

        // 结果展示
        if (this.result && !this.loading) {
          Column() {
            Text('💡 智能推荐')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 12 })

            this.buildFormattedText(this.result.summary)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .margin({ left: 16, right: 16, top: 16, bottom: 20 })

          // POI列表展示
          if (this.result.items && this.result.items.length > 0) {
            Column() {
              Text('📍 推荐地点')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 12 })

              ForEach(this.result.items, (item: PoiItem, index: number) => {
                this.buildPoiItem(item, index)
              })
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .margin({ left: 16, right: 16, bottom: 20 })
            .alignItems(HorizontalAlign.Start)
          }
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8')
    .bindSheet(this.showCompanionPicker, this.buildCompanionPickerDialog(), {
      height: '50%',
      dragBar: true,
      showClose: false,
    })
  }


  @Builder
  buildFormItem(icon: string, label: string, placeholder: string, value: string, onChange: (value: string) => void, required?: boolean) {
    Column() {
      Row() {
        Text(icon)
          .fontSize(16)
        Text(label)
          .fontSize(14)
          .fontColor('#333333')
          .margin({ left: 8 })
        if (required) {
          Text('*')
            .fontSize(14)
            .fontColor('#FF6B6B')
            .margin({ left: 2 })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ bottom: 8 })

      TextInput({ placeholder: placeholder })
        .width('100%')
        .height(44)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({
          width: 1,
          color: '#E0E0E0',
        })
        .onChange((text: string) => {
          onChange(text);
        })
    }
    .width('100%')
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildCheckbox(icon: string, label: string, checked: boolean, onChange: (value: boolean) => void) {
    Row() {
      Checkbox()
        .select(checked)
        .selectedColor('#007DFF')
        .onChange((isChecked: boolean) => {
          onChange(isChecked);
        })
      Text(`${icon} ${label}`)
        .fontSize(14)
        .fontColor('#333333')
        .margin({ left: 8 })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .margin({ bottom: 12 })
  }


  @Builder
  buildCityPickerItem(icon: string, label: string, placeholder: string, value: string, required?: boolean) {
    Column() {
      Row() {
        Text(icon)
          .fontSize(16)
        Text(label)
          .fontSize(14)
          .fontColor('#333333')
          .margin({ left: 8 })
        if (required) {
          Text('*')
            .fontSize(14)
            .fontColor('#FF6B6B')
            .margin({ left: 2 })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ bottom: 8 })

      Row() {
        TextInput({ placeholder: placeholder, text: value })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .border({
            width: 1,
            color: '#E0E0E0',
          })
          .enabled(false)
          .onClick(() => {
            if (required) {
              this.showCityPicker = true;
            } else {
              this.showDeparturePicker = true;
            }
          })

        Text('▼')
          .fontSize(16)
          .fontColor('#666666')
          .margin({ left: 8 })
          .onClick(() => {
            if (required) {
              this.showCityPicker = true;
            } else {
              this.showDeparturePicker = true;
            }
          })
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  // 获取城市建议列表（用于模糊搜索）
  private getCitySuggestions(searchText: string, maxResults: number = 10): string[] {
    if (!searchText.trim()) {
      return [];
    }
    const searchLower = searchText.toLowerCase();
    const matches: string[] = [];
    for (const city of this.cities) {
      if (city.includes(searchText) || city.toLowerCase().includes(searchLower)) {
        matches.push(city);
        if (matches.length >= maxResults) {
          break;
        }
      }
    }
    return matches;
  }

  @Builder
  buildCityInputItem(icon: string, label: string, placeholder: string, value: string, required: boolean, type: string) {
    Column() {
      Row() {
        Text(icon)
          .fontSize(16)
        Text(label)
          .fontSize(14)
          .fontColor('#333333')
          .margin({ left: 8 })
        if (required) {
          Text('*')
            .fontSize(14)
            .fontColor('#FF6B6B')
            .margin({ left: 2 })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ bottom: 8 })

      TextInput({ placeholder: placeholder, text: value })
        .width('100%')
        .height(44)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .border({
          width: 1,
          color: '#E0E0E0',
        })
        .onChange((text: string) => {
          if (type === 'destination') {
            this.destination = text;
          } else {
            this.departure = text;
          }
        })
    }
    .width('100%')
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildCityPickerDialog(type: string) {
    Column() {
      // 标题栏
      Row() {
        Text(type === 'destination' ? '选择目的地' : '选择出发地')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('取消')
          .type(ButtonType.Normal)
          .fontSize(14)
          .backgroundColor('#F5F5F5')
          .fontColor('#333333')
          .onClick(() => {
            if (type === 'destination') {
              this.showCityPicker = false;
              this.citySearchText = '';
            } else {
              this.showDeparturePicker = false;
              this.departureSearchText = '';
            }
          })
      }
      .width('100%')
      .padding(16)
      .borderRadius({ topLeft: 12, topRight: 12 })
      .backgroundColor('#FFFFFF')

      // 搜索框
      Row() {
        TextInput({ 
          placeholder: '搜索城市', 
          text: type === 'destination' ? this.citySearchText : this.departureSearchText 
        })
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .backgroundColor('#F5F5F5')
          .borderRadius(20)
          .onChange((text: string) => {
            if (type === 'destination') {
              this.citySearchText = text;
            } else {
              this.departureSearchText = text;
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor('#FFFFFF')

      // 城市列表（按字母分组）
      Scroll() {
        Column() {
          ForEach(
            Array.from((type === 'destination' ? this.getFilteredCities() : this.getFilteredDepartureCities()).entries())
              .sort((a, b) => a[0].localeCompare(b[0])), 
            (item: [string, string[]]) => {
              Column() {
                // 字母标题
                Row() {
                  Text(item[0])
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#007DFF')
                    .padding({ left: 16, top: 12, bottom: 8 })
                }
                .width('100%')
                .backgroundColor('#F8F8F8')

                // 城市列表
                Column() {
                  ForEach(item[1], (city: string) => {
                    Row() {
                      Text(city)
                        .fontSize(15)
                        .fontColor('#333333')
                        .layoutWeight(1)
                      if ((type === 'destination' ? this.destination : this.departure) === city) {
                        Text('✓')
                          .fontSize(16)
                          .fontColor('#007DFF')
                          .margin({ right: 16 })
                      }
                    }
                    .width('100%')
                    .height(48)
                    .padding({ left: 32, right: 16 })
                    .backgroundColor((type === 'destination' ? this.destination : this.departure) === city ? '#F0F7FF' : '#FFFFFF')
                    .onClick(() => {
                      if (type === 'destination') {
                        this.destination = city;
                        this.showCityPicker = false;
                        this.citySearchText = '';
                      } else {
                        this.departure = city;
                        this.showDeparturePicker = false;
                        this.departureSearchText = '';
                      }
                    })
                  })
                }
                .width('100%')
              }
              .width('100%')
            }
          )
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .borderRadius(12)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  buildCompanionPickerItem(icon: string, label: string, value: string) {
    Column() {
      Row() {
        Text(icon)
          .fontSize(16)
        Text(label)
          .fontSize(14)
          .fontColor('#333333')
          .margin({ left: 8 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ bottom: 8 })

      Row() {
        TextInput({ placeholder: '选择同行人数', text: value })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .border({
            width: 1,
            color: '#E0E0E0',
          })
          .enabled(false)
          .onClick(() => {
            this.showCompanionPicker = true;
          })

        Text('▼')
          .fontSize(16)
          .fontColor('#666666')
          .margin({ left: 8 })
          .onClick(() => {
            this.showCompanionPicker = true;
          })
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  buildCompanionPickerDialog() {
    Column() {
      // 标题栏
      Row() {
        Text('选择同行人数')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        Button('取消')
          .type(ButtonType.Normal)
          .fontSize(14)
          .backgroundColor('#F5F5F5')
          .fontColor('#333333')
          .onClick(() => {
            this.showCompanionPicker = false;
          })
      }
      .width('100%')
      .padding(16)
      .borderRadius({ topLeft: 12, topRight: 12 })
      .backgroundColor('#FFFFFF')

      // 选项列表
      Column() {
        ForEach(this.companionOptions, (option: string) => {
          Row() {
            if (this.companions === option) {
              Text('✓')
                .fontSize(16)
                .fontColor('#007DFF')
                .margin({ right: 12 })
            } else {
              Text('')
                .fontSize(16)
                .width(20)
                .margin({ right: 12 })
            }
            Text(option)
              .fontSize(15)
              .fontColor('#333333')
              .layoutWeight(1)
          }
          .width('100%')
          .height(56)
          .padding({ left: 16, right: 16 })
          .backgroundColor(this.companions === option ? '#F0F7FF' : '#FFFFFF')
          .onClick(() => {
            this.companions = option;
            this.showCompanionPicker = false;
          })
        })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .borderRadius(12)
    .backgroundColor('#FFFFFF')
  }

  // 清理markdown格式标记
  private cleanMarkdown(text: string): string {
    return text
      // 移除标题标记
      .replace(/^#{1,6}\s+/gm, '')
      // 移除粗体标记，保留文本
      .replace(/\*\*(.*?)\*\*/g, '$1')
      // 移除斜体标记
      .replace(/\*(.*?)\*/g, '$1')
      // 移除代码块标记
      .replace(/```[\s\S]*?```/g, '')
      // 移除行内代码标记
      .replace(/`([^`]+)`/g, '$1')
      // 处理链接，保留文本
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      // 移除分隔线
      .replace(/^---+$/gm, '')
      // 移除列表标记，保留文本
      .replace(/^[-*+]\s+/gm, '')
      .replace(/^\d+\.\s+/gm, '')
      // 清理多余空行
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }

  // 将数字转换为中文大写数字
  private numberToChinese(num: number): string {
    const chineseNumbers = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
    if (num <= 10) {
      return chineseNumbers[num];
    } else if (num < 20) {
      return '十' + (num > 10 ? chineseNumbers[num % 10] : '');
    } else if (num < 100) {
      const tens = Math.floor(num / 10);
      const ones = num % 10;
      return chineseNumbers[tens] + '十' + (ones > 0 ? chineseNumbers[ones] : '');
    }
    return String(num);
  }

  // 将"第X天"中的数字转换为中文大写
  private convertDayNumber(line: string): string {
    const match = line.match(/^第(\d+)天/);
    if (match) {
      const dayNum = parseInt(match[1], 10);
      const chineseDay = this.numberToChinese(dayNum);
      return line.replace(/^第\d+天/, `第${chineseDay}天`);
    }
    return line;
  }

  // 检查是否是"第X天"标题行
  private isDayTitle(line: string): boolean {
    return /^第\d+天/.test(line.trim());
  }

  // 解析并渲染格式化文本
  @Builder
  buildFormattedText(text: string) {
    Column() {
      ForEach(this.cleanMarkdown(text).split('\n'), (line: string, index: number) => {
        if (line.trim() === '') {
          Blank()
            .height(8)
        } else {
          // 检查是否是"第X天"标题
          if (this.isDayTitle(line)) {
            Text(this.convertDayNumber(line))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1F1F1F')
              .lineHeight(28)
              .margin({ top: 12, bottom: 8 })
              .alignSelf(ItemAlign.Start)
          } else {
            Text(line)
              .fontSize((line.length < 50 && !line.includes('：') && !line.includes(':')) ? 17 : 15)
              .fontWeight((line.length < 50 && !line.includes('：') && !line.includes(':')) ? FontWeight.Bold : FontWeight.Normal)
              .fontColor((line.length < 50 && !line.includes('：') && !line.includes(':')) ? '#1F1F1F' : '#333333')
              .lineHeight(24)
              .margin({ bottom: 6 })
              .alignSelf(ItemAlign.Start)
          }
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // 构建POI项展示
  @Builder
  buildPoiItem(item: PoiItem, index: number) {
    Column() {
      Row() {
        // POI图片
        if (item.image) {
          Image(item.image)
            .width(100)
            .height(100)
            .borderRadius(8)
            .objectFit(ImageFit.Cover)
            .alt('POI图片')
            .onError(() => {
              // 图片加载失败时的处理
            })
        } else {
          // 占位图片
          Column() {
            Text('📍')
              .fontSize(40)
              .fontColor('#CCCCCC')
          }
          .width(100)
          .height(100)
          .borderRadius(8)
          .backgroundColor('#F5F5F5')
          .justifyContent(FlexAlign.Center)
        }

        // POI信息
        Column() {
          Text(item.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1F1F1F')
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 6 })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          if (item.address) {
            Text(item.address)
              .fontSize(13)
              .fontColor('#666666')
              .alignSelf(ItemAlign.Start)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ bottom: 4 })
          }

          Row() {
            if (item.score !== undefined) {
              Text(`⭐ ${item.score.toFixed(1)}`)
                .fontSize(12)
                .fontColor('#FF9500')
            }
            if (item.distance !== undefined) {
              Text(`距离 ${item.distance}m`)
                .fontSize(12)
                .fontColor('#999999')
                .margin({ left: item.score !== undefined ? 12 : 0 })
            }
            if (item.tel) {
              Text(`📞 ${item.tel}`)
                .fontSize(12)
                .fontColor('#999999')
                .margin({ left: 12 })
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          .margin({ top: 4 })
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
        .height(100)
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ bottom: 12 })
    .shadow({
      radius: 4,
      color: '#1F000000',
      offsetX: 0,
      offsetY: 2,
    })
  }
}

