from pathlib import Path
import xml.etree.ElementTree as ET
import json,re
root=Path(__file__).parent
upstream=root.parent/'deutsia-radio-upstream/app/src/main/res'
def load(locale):
 p=upstream/('values' if locale=='en' else 'values-'+locale)/'strings.xml'
 return {el.attrib['name']:''.join(el.itertext()).replace("\\'","'").replace('\\"','"').replace('\\n','\n') for el in ET.parse(p).getroot().findall('string')}
base=load('en');zh=load('zh')
alias={'发现电台':'tab_browse','发现':'tab_browse','我的电台':'tab_radios','设置':'tab_settings','正在收听':'tab_now_playing','添加电台':'dialog_add_station','编辑电台':'dialog_edit_station','心动收藏':'auto_node_favorites','收藏':'auto_node_favorites','播放队列':'sort_custom','最近收听':'browse_history','历史':'browse_history','类型':'filter_genre','国家':'filter_country','管理类型':'manage_genres','重命名':'genre_action_rename','删除类型':'genre_action_delete','定时停止':'settings_sleep_timer','深色':'settings_theme_dark','浅色':'settings_theme_light','跟随系统':'settings_theme_system_default','外观':'settings_appearance','电台名称':'hint_station_name','名称':'hint_station_name','流媒体 URL':'hint_stream_url','导入电台…':'settings_import_from_file','取消':'button_cancel','保存':'button_save','编辑':'button_edit','重置':'button_reset','启用':'settings_sleep_timer_enable','语言':'settings_language','全部':'filter_all_genres'}
# Preserve upstream translations for matching labels, without exposing Tor controls.
for k,v in zh.items():
 if 'tor' not in k.lower() and '\n' not in v and len(v)<50: alias.setdefault(v,k)
manual={'此刻，听见世界':'Tune into your world','跨过距离，让世界的声音在这里相遇。':'Discover voices from around the world.','每一种心情，都有属于它的频率。':'A frequency for every mood.','音乐、故事与远方，找到你的专属频道。 ':'Music, stories, and places. Find your frequency.','搜索电台、发现好声音':'Search stations','为你发现':'Discover for you','电台列表':'Stations','等待一段好声音':'Your next sound awaits','世界很大，点一下开始探索':'A world of sound awaits','浏览热门电台':'Explore popular stations','这里还没有电台':'No stations here yet','添加一个电台':'Add a station','搜索':'Search','热门':'Popular','爵士':'Jazz','古典':'Classical','电子':'Electronic','新闻':'News','放松':'Ambient','播放':'Play','暂停':'Pause','停止':'Stop','完成':'Done','主题色':'Accent color','紫色':'Purple','蓝色':'Blue','绿色':'Green','橙色':'Orange','粉色':'Pink','青色':'Teal','自定义':'Custom','自定义时间…':'Custom timer…','国家（如 China）':'Country (e.g. China)','原作者 GitHub 主页':'Original author on GitHub','原项目 deutsia/deutsia-radio':'Original project: deutsia/deutsia-radio','移植与界面设计：Billson':'Port and interface design: Billson','AI 辅助开发：OpenAI Codex':'AI-assisted development: OpenAI Codex','使用模型：gpt-6.1-sol':'Model used: gpt-6.1-sol','电台目录':'Station directories','资料管理':'Library management','本地安全':'Local security','录音':'Recording','网络':'Network','强制代理':'Force proxy','录音文件':'Recordings','导入与导出':'Import and export','停止播放':'Stop playback','开始录音':'Start recording','停止录音':'Stop recording','封面 URL':'Artwork URL','名称':'Name','协议':'Protocol','主机':'Host','端口':'Port','用户名':'Username','密码':'Password','认证':'Authentication','代理协议':'Proxy protocol','加入我的电台':'Add to library','加入播放队列':'Add to queue','删除电台':'Delete station','取消定时':'Cancel timer','上移':'Move up','下移':'Move down','从队列移除':'Remove from queue','筛选名称或类型':'Filter name or genre','名称':'Name','最近':'Recent','自定义代理':'Custom proxy','直接连接':'Direct connection','直连':'Direct connection','清除历史记录':'Clear history'}
locales=['en','ar','de','es','fa','fr','hi','it','ja','ko','my','pt','ru','tr','uk','vi','zh']
for locale in locales:
 translated=load(locale)
 out={}
 for literal,key in alias.items():
  if key in base and '%' not in base[key] and key in translated: out[literal]=literal if locale=='zh' else translated[key]
 for literal,value in manual.items(): out.setdefault(literal,literal if locale=='zh' else value)
 folder=root/'Resources/Localization'/('zh-Hans.lproj' if locale=='zh' else locale+'.lproj');folder.mkdir(parents=True,exist_ok=True)
 (folder/'Localizable.strings').write_text('// Derived from deutsia radio translations, Apache-2.0. New Apple UI copy may fall back to English.\n'+'\n'.join(json.dumps(k,ensure_ascii=False)+' = '+json.dumps(v,ensure_ascii=False)+';' for k,v in sorted(out.items()))+'\n')
print('Generated',len(locales),'locales')
