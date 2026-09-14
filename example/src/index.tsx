/**
 * MIT License
 * 
 * Copyright (C) 2026 Huawei Device Co., Ltd.
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
/**
 * react-native-svga 鸿蒙适配 Example
 *
 * 覆盖库全部公开能力：
 * - SVGAModule.getAssets（require 本地 svga 资源解析）
 * - SVGAModule.isCached（缓存查询，真实返回值展示）
 * - SVGAModule.advanceDownload（网络批量预下载）
 * - SVGAView 播放（source/loops/clearsAfterStop/currentState/toFrame/toPercentage）
 * - SVGAView 实例方法：load/startAnimation/pauseAnimation/stopAnimation/
 *   clearAnimation/stepToFrame/stepToPercentage
 * - 事件回调：onFinished/onFrame/onPercentage（真实帧号与进度展示）
 */

import React, {useRef, useState} from 'react';
import {
  Button,
  Dimensions,
  Modal,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import {SVGAView, SVGAModule} from 'react-native-svga';

const {width: kScreenW} = Dimensions.get('window');

// 网络样例（SVGA-Samples；github raw 在部分网络不可达，采用 jsDelivr CDN 镜像 + 原 github 地址各保留）
const svgaList_net = [
  'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/heartbeat.svga',
  'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/rose.svga',
  'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/angel.svga',
  'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/posche.svga',
  'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/halloween.svga',
  'https://cdn.jsdelivr.net/gh/yyued/SVGA-Samples@master/kingset.svga',
];

// 本地打包资源（metro assetExts 已加 svga）
const svgaList_native = [
  require('../assets/svga/angel.svga'),
  require('../assets/svga/rose.svga'),
];

type LogLine = {key: number; text: string};

const App = () => {
  const [modal, setModal] = useState(false);
  const [url, setUrl] = useState('');
  const [loops, setLoops] = useState(1);
  const [clearsAfterStop, setClearsAfterStop] = useState(true);
  const [frameInput, setFrameInput] = useState('30');
  const [curFrame, setCurFrame] = useState(-1);
  const [curPercentage, setCurPercentage] = useState(0);
  const [finishedCount, setFinishedCount] = useState(0);
  const [logs, setLogs] = useState<LogLine[]>([]);
  const [cachedInfo, setCachedInfo] = useState('未查询');
  const svgaRef = useRef<SVGAView>(null);
  const logSeq = useRef(0);

  const appendLog = (text: string) => {
    logSeq.current += 1;
    setLogs(prev => [{key: logSeq.current, text}, ...prev].slice(0, 8));
  };

  /** 打开播放器（本地资源先 getAssets 解析为原生 URI） */
  const open = (source: string) => {
    setCurFrame(-1);
    setCurPercentage(0);
    setFinishedCount(0);
    setLogs([]);
    setUrl(source);
    setModal(true);
  };

  const openNative = (asset: number) => {
    const resolved = SVGAModule.getAssets(asset);
    // dev 模式：http 地址直用；bundle 模式：metro 产物在 rawfile 下深达 3 层
    // （assets/assets/svga/），超过 2 层的 rawfile 子路径系统读不到
    // （getRawFileContent 失败，与目录名无关），故取裸文件名读 rawfile 根目录。
    const uri = resolved.startsWith('http')
      ? resolved
      : resolved.split('/').pop() ?? resolved;
    appendLog(`getAssets -> ${uri}`);
    open(uri);
  };

  /** 预加载全部（真实 advanceDownload） */
  const preloadAll = () => {
    appendLog(`advanceDownload(${svgaList_net.length} 个网络地址)`);
    SVGAModule.advanceDownload(svgaList_net);
  };

  /** 缓存查询（真实 isCached 返回值） */
  const checkCache = () => {
    const target = svgaList_net[0];
    setCachedInfo('查询中...');
    SVGAModule.isCached(target)
      .then((cached: boolean) => {
        setCachedInfo(cached ? '已缓存 ✓' : '未缓存 ✗');
        appendLog(`isCached -> ${cached}`);
      })
      .catch((e: unknown) => {
        setCachedInfo(`查询失败: ${e}`);
      });
  };

  return (
    <SafeAreaView style={styles.root}>
      <Text style={styles.title}>react-native-svga (HarmonyOS)</Text>

      <View style={styles.row}>
        <View style={styles.btn}>
          <Button title="预加载全部" onPress={preloadAll} />
        </View>
        <View style={styles.btn}>
          <Button title="查询缓存" onPress={checkCache} />
        </View>
      </View>
      <Text style={styles.cacheText}>缓存状态（heartbeat.svga）: {cachedInfo}</Text>

      <ScrollView style={styles.list}>
        {svgaList_net.map((item, index) => (
          <Button
            key={item}
            title={`网络${index + 1}: ${item.split('/').pop()}`}
            onPress={() => open(item)}
          />
        ))}
        {svgaList_native.map((item, index) => (
          <Button
            key={index}
            title={`本地${index + 1}: ${index === 0 ? 'angel.svga' : 'rose.svga'}`}
            onPress={() => openNative(item)}
          />
        ))}
        <View style={{height: 20}} />
      </ScrollView>

      <Modal transparent visible={modal} onRequestClose={() => setModal(false)}>
        <View style={styles.modalMask}>
          <View style={styles.modalCard}>
            <Text style={styles.urlText} numberOfLines={1}>
              {url.split('/').pop()}
            </Text>
            {/* 条件渲染：关闭 Modal 即卸载 SVGAView（触发 componentWillUnmount → stopAnimation，对齐原 example） */}
            {modal && (
              <SVGAView
                ref={svgaRef}
                source={url}
                loops={loops}
                clearsAfterStop={clearsAfterStop}
                style={styles.player}
                onFinished={() => {
                  setFinishedCount(c => c + 1);
                  appendLog('onFinished');
                }}
                onFrame={(value: number) => {
                  setCurFrame(value);
                }}
                onPercentage={(value: number) => {
                  setCurPercentage(value);
                }}
              />
            )}

            <Text style={styles.statusText}>
              当前帧: {curFrame} 进度: {curPercentage.toFixed(2)} 播完次数:{' '}
              {finishedCount} loops: {loops}
              {clearsAfterStop ? ' 播完清屏' : ' 播完保留'}
            </Text>

            <View style={styles.row}>
              <View style={styles.btn}>
                <Button title="播放" onPress={() => svgaRef.current?.startAnimation()} />
              </View>
              <View style={styles.btn}>
                <Button title="暂停" onPress={() => svgaRef.current?.pauseAnimation()} />
              </View>
              <View style={styles.btn}>
                <Button title="停止" onPress={() => svgaRef.current?.stopAnimation()} />
              </View>
              <View style={styles.btn}>
                <Button title="清空" onPress={() => svgaRef.current?.clearAnimation()} />
              </View>
            </View>

            <View style={styles.row}>
              <View style={styles.btn}>
                <Button
                  title="循环0/1/3"
                  onPress={() => setLoops(l => (l === 0 ? 1 : l === 1 ? 3 : 0))}
                />
              </View>
              <View style={styles.btn}>
                <Button
                  title="清屏开关"
                  onPress={() => setClearsAfterStop(v => !v)}
                />
              </View>
              <View style={styles.btn}>
                <Button
                  title="load(本地angel)"
                  onPress={() => {
                    const uri = SVGAModule.getAssets(svgaList_native[0]);
                    appendLog(`load -> ${uri}`);
                    svgaRef.current?.load(uri);
                  }}
                />
              </View>
            </View>

            <View style={styles.row}>
              <TextInput
                style={styles.frameInput}
                value={frameInput}
                keyboardType="number-pad"
                onChangeText={(t: string) => setFrameInput(t)}
              />
              <View style={styles.btn}>
                <Button
                  title="跳帧(暂停)"
                  onPress={() =>
                    svgaRef.current?.stepToFrame(parseInt(frameInput, 10) || 0, false)
                  }
                />
              </View>
              <View style={styles.btn}>
                <Button
                  title="跳帧(播放)"
                  onPress={() =>
                    svgaRef.current?.stepToFrame(parseInt(frameInput, 10) || 0, true)
                  }
                />
              </View>
            </View>

            <View style={styles.row}>
              <View style={styles.btn}>
                <Button
                  title="25%"
                  onPress={() => svgaRef.current?.stepToPercentage(0.25, false)}
                />
              </View>
              <View style={styles.btn}>
                <Button
                  title="50%"
                  onPress={() => svgaRef.current?.stepToPercentage(0.5, false)}
                />
              </View>
              <View style={styles.btn}>
                <Button
                  title="75%播放"
                  onPress={() => svgaRef.current?.stepToPercentage(0.75, true)}
                />
              </View>
              <View style={styles.btn}>
                <Button title="关闭" color="red" onPress={() => setModal(false)} />
              </View>
            </View>

            <View style={styles.logBox}>
              <Text style={styles.logTitle}>事件日志（最近 8 条）</Text>
              {logs.map(line => (
                <Text key={line.key} style={styles.logLine}>
                  {line.text}
                </Text>
              ))}
            </View>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  root: {flex: 1, backgroundColor: '#F3F3F3'},
  title: {fontSize: 20, textAlign: 'center', marginVertical: 8, color: '#222222'},
  row: {flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', marginVertical: 2},
  btn: {margin: 2},
  cacheText: {fontSize: 12, color: '#555555', textAlign: 'center'},
  list: {flex: 1},
  modalMask: {flex: 1, backgroundColor: 'rgba(0,0,0,0.5)'},
  modalCard: {
    flex: 1,
    marginTop: 40,
    marginHorizontal: 8,
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    padding: 8,
  },
  urlText: {fontSize: 14, color: '#222222', textAlign: 'center'},
  player: {width: kScreenW - 48, height: 260, backgroundColor: '#101010'},
  statusText: {fontSize: 12, color: '#444444', marginVertical: 4},
  frameInput: {
    width: 56,
    height: 32,
    borderWidth: 1,
    borderColor: '#999999',
    borderRadius: 4,
    textAlign: 'center',
    margin: 2,
  },
  logBox: {flex: 1, borderTopWidth: 1, borderColor: '#DDDDDD', paddingTop: 4},
  logTitle: {fontSize: 12, color: '#666666'},
  logLine: {fontSize: 11, color: '#888888'},
});

export default App;
