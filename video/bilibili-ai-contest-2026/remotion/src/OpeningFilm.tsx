import React from 'react';
import {
  AbsoluteFill,
  interpolate,
  OffthreadVideo,
  Sequence,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

const C = {
  black: '#030504',
  ink: '#0A100D',
  paper: '#EEE8D8',
  jade: '#39D39F',
  gold: '#D8A84E',
  red: '#E04A43',
  muted: '#A7B0AA',
};

const sans = '"Microsoft YaHei", "Source Han Sans SC", sans-serif';
const serif = '"Source Han Serif SC", "Noto Serif CJK SC", SimSun, serif';
const clamp = {extrapolateLeft: 'clamp' as const, extrapolateRight: 'clamp' as const};

const FullVideo: React.FC<{
  src: string;
  startFrom?: number;
  style?: React.CSSProperties;
}> = ({src, startFrom = 0, style}) => <OffthreadVideo
  src={staticFile(src)}
  startFrom={startFrom}
  muted
  style={{position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', ...style}}
/>;

const FilmTexture: React.FC<{opacity?: number}> = ({opacity = .18}) => {
  const frame = useCurrentFrame();
  return <>
    <div style={{position: 'absolute', inset: 0, pointerEvents: 'none', opacity, backgroundImage: 'repeating-linear-gradient(0deg, rgba(255,255,255,.04) 0, rgba(255,255,255,.04) 1px, transparent 1px, transparent 7px)'}}/>
    <div style={{position: 'absolute', inset: -80, pointerEvents: 'none', transform: `translate(${(frame % 3) - 1}px, ${(frame % 5) - 2}px)`, background: 'radial-gradient(circle, transparent 42%, rgba(0,0,0,.72) 100%)'}}/>
  </>;
};

const ExplosionScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const title = spring({frame: frame - 10, fps, config: {damping: 16, stiffness: 90}});
  const scale = interpolate(frame, [0, 105], [1.02, 1.13], clamp);
  const flash = interpolate(frame, [0, 2, 8], [.95, .45, 0], clamp);
  return <AbsoluteFill style={{backgroundColor: C.black, color: C.paper, fontFamily: sans, overflow: 'hidden'}}>
    <FullVideo src="generated/tianqi-explosion.mp4" style={{transform: `scale(${scale})`, filter: 'contrast(1.08) saturate(.82) brightness(.78)'}}/>
    <div style={{position: 'absolute', inset: 0, background: 'linear-gradient(90deg, rgba(2,4,3,.9) 0%, rgba(2,4,3,.5) 42%, transparent 72%)'}}/>
    <div style={{position: 'absolute', left: 190, top: 580, width: 2180, opacity: title, transform: `translateY(${(1 - title) * 80}px)`}}>
      <div style={{fontSize: 50, color: C.gold, letterSpacing: 10, marginBottom: 44}}>天启六年 · 王恭厂</div>
      <div style={{fontFamily: serif, fontSize: 154, lineHeight: 1.28, textShadow: '0 10px 40px rgba(0,0,0,.7)'}}>
        我把一个 <span style={{color: C.jade}}>AI</span>，<br/>扔进了一场灾变。
      </div>
    </div>
    <FilmTexture opacity={.12}/>
    <div style={{position: 'absolute', inset: 0, pointerEvents: 'none', background: `rgba(255,236,190,${flash})`, mixBlendMode: 'screen'}}/>
  </AbsoluteFill>;
};

const CharacterScene: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({frame: frame - 6, fps, config: {damping: 18, stiffness: 88}});
  const scan = interpolate(frame, [18, 115], [0, 1], clamp);
  return <AbsoluteFill style={{backgroundColor: C.black, color: C.paper, fontFamily: sans, overflow: 'hidden'}}>
    <FullVideo src="generated/tianqi-ai-dialogue.mp4" style={{transform: `scale(${1.05 + scan * .04})`, transformOrigin: '76% 48%', filter: 'brightness(.65) saturate(.82) contrast(1.08)'}}/>
    <div style={{position: 'absolute', inset: 0, background: 'linear-gradient(90deg, rgba(2,5,3,.94) 0%, rgba(2,5,3,.76) 42%, rgba(2,5,3,.1) 76%)'}}/>
    <div style={{position: 'absolute', left: 190, top: 630, width: 1940, opacity: enter, transform: `translateX(${(1 - enter) * -90}px)`}}>
      <div style={{fontFamily: serif, fontSize: 132, lineHeight: 1.32}}>它不是聊天框。</div>
      <div style={{fontFamily: serif, fontSize: 132, lineHeight: 1.32, color: C.jade}}>它在扮演这里的人。</div>
      <div style={{display: 'flex', gap: 28, marginTop: 64, fontSize: 52, color: C.muted}}>
        {['隐瞒', '试探', '临时改口'].map((label, index) => <div key={label} style={{padding: '22px 38px', border: `1px solid ${index === 2 ? C.gold : 'rgba(238,232,216,.28)'}`, background: 'rgba(3,5,4,.58)', opacity: interpolate(frame, [28 + index * 16, 48 + index * 16], [0, 1], clamp), transform: `translateY(${interpolate(frame, [28 + index * 16, 48 + index * 16], [30, 0], clamp)}px)`}}>{label}</div>)}
      </div>
    </div>
    <div style={{position: 'absolute', left: `${32 + scan * 36}%`, top: 0, bottom: 0, width: 4, background: `linear-gradient(transparent, ${C.jade}, transparent)`, opacity: .55, boxShadow: `0 0 40px ${C.jade}`}}/>
    <FilmTexture opacity={.1}/>
  </AbsoluteFill>;
};

const StatePanel: React.FC<{
  title: string;
  fact: string;
  result: string;
  side: 'left' | 'right';
  startFrom: number;
  delay: number;
}> = ({title, fact, result, side, startFrom, delay}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({frame: frame - delay, fps, config: {damping: 17, stiffness: 95}});
  const active = side === 'right';
  return <div style={{position: 'absolute', top: 420, [side]: 170, width: 1690, height: 1260, overflow: 'hidden', border: `2px solid ${active ? C.jade : 'rgba(238,232,216,.24)'}`, background: C.ink, boxShadow: '0 38px 100px rgba(0,0,0,.55)', opacity: enter, transform: `translateY(${(1 - enter) * 90}px)`}}>
    <FullVideo src="generated/tianqi-ai-dialogue.mp4" startFrom={startFrom} style={{filter: `brightness(${active ? .58 : .38}) saturate(${active ? .82 : .28})`, transform: 'scale(1.16)', transformOrigin: '68% 46%'}}/>
    <div style={{position: 'absolute', inset: 0, background: 'linear-gradient(0deg, rgba(2,5,3,.96) 0%, rgba(2,5,3,.52) 50%, rgba(2,5,3,.12) 100%)'}}/>
    <div style={{position: 'absolute', left: 58, top: 54, padding: '18px 28px', fontSize: 42, color: active ? C.jade : C.muted, background: 'rgba(3,5,4,.82)', borderLeft: `6px solid ${active ? C.jade : C.muted}`}}>{title}</div>
    <div style={{position: 'absolute', left: 58, right: 58, bottom: 62}}>
      <div style={{fontSize: 40, color: active ? C.gold : C.muted, marginBottom: 20}}>{fact}</div>
      <div style={{fontFamily: serif, fontSize: 66, lineHeight: 1.45, color: active ? C.paper : '#C4CBC7'}}>{result}</div>
    </div>
  </div>;
};

const EvidenceChangesAnswer: React.FC = () => {
  const frame = useCurrentFrame();
  const underline = interpolate(frame, [28, 90], [0, 1], clamp);
  return <AbsoluteFill style={{background: 'linear-gradient(135deg, #030504, #08120E)', color: C.paper, fontFamily: sans, overflow: 'hidden'}}>
    <div style={{position: 'absolute', left: 0, right: 0, top: 142, textAlign: 'center'}}>
      <div style={{fontFamily: serif, fontSize: 110, letterSpacing: 3}}>同一个人，会根据你掌握的证据改口。</div>
      <div style={{width: 1500, height: 4, margin: '38px auto 0', background: `linear-gradient(90deg, transparent, ${C.jade}, transparent)`, transform: `scaleX(${underline})`}}/>
    </div>
    <StatePanel side="left" title="玩家尚未取得残页" fact="可用事实：没有交割残页" result="不能引用这份材料，也不能讨论其中的异常。" startFrom={20} delay={10}/>
    <StatePanel side="right" title="玩家交出残页后" fact="可用事实：异常领讫戳" result="可以讨论记录异常，但不能把它说成爆炸原因。" startFrom={340} delay={32}/>
    <div style={{position: 'absolute', left: '50%', top: 980, width: 100, height: 100, borderTop: `8px solid ${C.gold}`, borderRight: `8px solid ${C.gold}`, transform: `translate(-60%,-50%) rotate(45deg) scale(${interpolate(frame, [45, 75], [.5, 1], clamp)})`, opacity: interpolate(frame, [38, 60], [0, 1], clamp)}}/>
    <FilmTexture opacity={.08}/>
  </AbsoluteFill>;
};

const FactBoundary: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const strike = interpolate(frame, [32, 68], [0, 1], clamp);
  const correction = spring({frame: frame - 68, fps, config: {damping: 15, stiffness: 100}});
  const shake = frame > 30 && frame < 70 ? Math.sin(frame * 2.7) * 9 : 0;
  return <AbsoluteFill style={{backgroundColor: C.black, color: C.paper, fontFamily: sans, overflow: 'hidden'}}>
    <FullVideo src="generated/tianqi-ai-dialogue.mp4" startFrom={360} style={{filter: 'brightness(.24) saturate(.55)', transform: 'scale(1.07)', transformOrigin: '72% 50%'}}/>
    <div style={{position: 'absolute', inset: 0, background: 'rgba(3,5,4,.66)'}}/>
    <div style={{position: 'absolute', left: 260, right: 260, top: 300, padding: '76px 90px', background: 'rgba(8,14,11,.93)', border: `1px solid rgba(238,232,216,.2)`, transform: `translateX(${shake}px)`}}>
      <div style={{fontSize: 48, color: C.red, letterSpacing: 8, marginBottom: 34}}>越界断言</div>
      <div style={{position: 'relative', display: 'inline-block', fontFamily: serif, fontSize: 112, lineHeight: 1.34}}>
        交割残页证明了爆炸成因。
        <div style={{position: 'absolute', left: -20, right: -20, top: '52%', height: 18, background: C.red, transform: `rotate(-2deg) scaleX(${strike})`, transformOrigin: 'left', boxShadow: '0 0 34px rgba(224,74,67,.65)'}}/>
      </div>
    </div>
    <div style={{position: 'absolute', left: 610, right: 610, top: 1040, padding: '64px 80px', background: 'rgba(5,15,11,.96)', borderLeft: `10px solid ${C.jade}`, opacity: correction, transform: `translateY(${(1 - correction) * 80}px)`}}>
      <div style={{fontSize: 48, color: C.jade, letterSpacing: 6, marginBottom: 28}}>内容包中的事实边界</div>
      <div style={{fontFamily: serif, fontSize: 88, lineHeight: 1.42}}>残页只能证明记录异常。<br/><span style={{color: C.gold}}>爆炸成因，仍然未决。</span></div>
    </div>
    <FilmTexture opacity={.1}/>
  </AbsoluteFill>;
};

const WorldSwitch: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const reveal = interpolate(frame, [5, 46], [0, 1], clamp);
  const title = spring({frame: frame - 28, fps, config: {damping: 16, stiffness: 92}});
  const fade = interpolate(frame, [48, 78], [0, .74], clamp);
  return <AbsoluteFill style={{backgroundColor: C.black, color: C.paper, fontFamily: sans, overflow: 'hidden'}}>
    <FullVideo src="generated/tianqi-ai-dialogue.mp4" startFrom={300} style={{filter: 'brightness(.58) saturate(.78)'}}/>
    <div style={{position: 'absolute', inset: 0, clipPath: `inset(0 0 0 ${(1 - reveal) * 100}%)`, boxShadow: '-30px 0 80px rgba(0,0,0,.8)'}}>
      <FullVideo src="generated/fantu-intro.mp4" style={{filter: 'brightness(.62) saturate(.84)'}}/>
    </div>
    <div style={{position: 'absolute', top: 0, bottom: 0, left: `${reveal * 100}%`, width: 8, background: C.gold, boxShadow: `0 0 60px ${C.gold}`, opacity: frame < 52 ? 1 : 0}}/>
    <div style={{position: 'absolute', inset: 0, background: `rgba(2,4,3,${fade})`}}/>
    <div style={{position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', textAlign: 'center', opacity: title, transform: `scale(${.82 + title * .18})`}}>
      <div>
        <div style={{fontFamily: serif, fontSize: 102, lineHeight: 1.4}}>不是一段剧情，<br/><span style={{color: C.jade}}>是一套可以更换故事的游戏框架。</span></div>
        <div style={{width: 1320, height: 4, margin: '58px auto 50px', background: `linear-gradient(90deg, transparent, ${C.gold}, transparent)`}}/>
        <div style={{fontFamily: serif, fontSize: 180, letterSpacing: 26}}>Narra</div>
      </div>
    </div>
    <FilmTexture opacity={.1}/>
  </AbsoluteFill>;
};

export const OpeningFilm: React.FC = () => <AbsoluteFill style={{backgroundColor: C.black}}>
  <Sequence from={0} durationInFrames={105}><ExplosionScene/></Sequence>
  <Sequence from={105} durationInFrames={135}><CharacterScene/></Sequence>
  <Sequence from={240} durationInFrames={150}><EvidenceChangesAnswer/></Sequence>
  <Sequence from={390} durationInFrames={120}><FactBoundary/></Sequence>
  <Sequence from={510} durationInFrames={90}><WorldSwitch/></Sequence>
</AbsoluteFill>;
