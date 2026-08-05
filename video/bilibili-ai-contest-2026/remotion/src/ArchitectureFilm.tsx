import React from 'react';
import {AbsoluteFill, Easing, Img, interpolate, Sequence, staticFile, useCurrentFrame} from 'remotion';

const P = {
  bg: '#0B1310',
  surface: '#121E1A',
  surface2: '#172620',
  text: '#E6ECE8',
  muted: '#AAB5AF',
  jade: '#34D399',
  amber: '#F59E0B',
  line: 'rgba(230,236,232,0.14)',
};

const sans = '"Microsoft YaHei", "Source Han Sans SC", sans-serif';
const serif = '"Source Han Serif SC", "Noto Serif CJK SC", SimSun, serif';
const mono = '"JetBrains Mono", Consolas, monospace';
const ease = Easing.bezier(0.16, 1, 0.3, 1);
const clamp = {extrapolateLeft: 'clamp' as const, extrapolateRight: 'clamp' as const, easing: ease};

const Shell: React.FC<React.PropsWithChildren> = ({children}) => {
  const frame = useCurrentFrame();
  const glow = interpolate(frame % 180, [0, 90, 180], [.08, .15, .08]);
  return <AbsoluteFill style={{backgroundColor: P.bg, color: P.text, fontFamily: sans, overflow: 'hidden'}}>
    <div style={{position: 'absolute', inset: 0, background: `radial-gradient(circle at 78% 34%, rgba(52,211,153,${glow}), transparent 34%), radial-gradient(circle at 18% 88%, rgba(245,158,11,.05), transparent 30%)`}}/>
    <div style={{position: 'absolute', inset: 0, opacity: .12, backgroundImage: 'repeating-linear-gradient(0deg, rgba(255,255,255,.025) 0, rgba(255,255,255,.025) 1px, transparent 1px, transparent 7px)'}}/>
    {children}
  </AbsoluteFill>;
};

const Fade: React.FC<React.PropsWithChildren<{duration: number}>> = ({duration, children}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 16, duration - 12, duration], [0, 1, 1, 0], clamp);
  return <div style={{position: 'absolute', inset: 0, opacity}}>{children}</div>;
};

const Logo: React.FC<{src: string; height: number}> = ({src, height}) => <Img src={staticFile(src)} style={{height, maxWidth: 280, objectFit: 'contain'}}/>;

const ProjectShot: React.FC<{src: string; dim?: number}> = ({src, dim = .62}) => {
  const frame = useCurrentFrame();
  return <>
    <Img src={staticFile(src)} style={{position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', filter: `brightness(${dim}) saturate(.8)`, transform: `scale(${1.02 + Math.sin(frame / 52) * .008})`}}/>
    <div style={{position: 'absolute', inset: 0, background: 'linear-gradient(180deg, transparent 32%, rgba(8,14,11,.94) 100%)'}}/>
  </>;
};

const Making: React.FC = () => {
  const frame = useCurrentFrame();
  const copyIn = interpolate(frame, [0, 24], [0, 1], clamp);
  const checkIn = interpolate(frame, [44, 92], [0, 1], clamp);
  return <Fade duration={270}>
    <div style={{position: 'absolute', left: 230, top: 745, width: 1500, opacity: copyIn, transform: `translateX(${(1 - copyIn) * -70}px)`}}>
      <div style={{fontFamily: serif, fontSize: 122, lineHeight: 1.34}}>AI 参与制作，<br/><span style={{color: P.jade}}>结果必须验证。</span></div>
    </div>
    <div style={{position: 'absolute', right: 230, top: 365, width: 1580, height: 1110, borderRadius: 28, overflow: 'hidden', background: P.surface, border: `1px solid ${P.line}`, boxShadow: '0 34px 110px rgba(0,0,0,.42)'}}>
      <ProjectShot src="tech/ai-dialogue.png"/>
      <div style={{position: 'absolute', left: 70, right: 70, bottom: 70, padding: '42px 52px', background: 'rgba(8,20,15,.94)', borderLeft: `9px solid ${P.jade}`, fontSize: 52, opacity: checkIn, transform: `translateY(${(1 - checkIn) * 52}px)`}}>
        内容引用检查通过
      </div>
    </div>
  </Fade>;
};

const ArchitectureCard: React.FC<React.PropsWithChildren<{left: number; width: number; delay: number}>> = ({left, width, delay, children}) => {
  const frame = useCurrentFrame();
  const enter = interpolate(frame, [delay, delay + 48], [0, 1], clamp);
  return <div style={{position: 'absolute', left, top: 610, width, height: 1040, borderRadius: 28, overflow: 'hidden', background: P.surface, border: `1px solid ${P.line}`, boxShadow: '0 30px 90px rgba(0,0,0,.34)', opacity: enter, transform: `translateY(${(1 - enter) * 65}px)`}}>{children}</div>;
};

const Architecture: React.FC = () => {
  const frame = useCurrentFrame();
  const flow = interpolate(frame, [92, 260], [0, 1], clamp);
  return <Fade duration={480}>
    <div style={{position: 'absolute', left: 230, top: 280, fontFamily: serif, fontSize: 104}}>AI 管表达，规则管事实。</div>

    <ArchitectureCard left={230} width={1080} delay={10}>
      <ProjectShot src="tech/fantu-gameplay.jpg"/>
      <div style={{position: 'absolute', left: 64, bottom: 72, display: 'flex', alignItems: 'center', gap: 38}}>
        <Logo src="tech/godot.svg" height={126}/>
        <div><div style={{fontSize: 64}}>Godot</div><div style={{fontSize: 46, color: P.muted, marginTop: 10}}>界面与演出</div></div>
      </div>
    </ArchitectureCard>

    <ArchitectureCard left={1390} width={1060} delay={34}>
      <div style={{position: 'absolute', inset: 0, display: 'grid', gridTemplateRows: '1fr 1fr'}}>
        <div style={{display: 'flex', alignItems: 'center', padding: '0 82px', gap: 54, borderBottom: `1px solid ${P.line}`}}>
          <Logo src="tech/go.svg" height={116}/>
          <div><div style={{fontSize: 66}}>Go</div><div style={{fontSize: 46, color: P.muted, marginTop: 12}}>规则与存档</div></div>
        </div>
        <div style={{display: 'flex', alignItems: 'center', padding: '0 82px', gap: 54}}>
          <div style={{fontFamily: mono, fontSize: 74}}>YAML</div>
          <div style={{fontSize: 46, color: P.muted, lineHeight: 1.5}}>人物、地点<br/>与世界事实</div>
        </div>
      </div>
    </ArchitectureCard>

    <ArchitectureCard left={2530} width={1080} delay={58}>
      <ProjectShot src="tech/ai-dialogue.png" dim={.56}/>
      <div style={{position: 'absolute', left: 64, bottom: 72}}>
        <div style={{fontSize: 64, color: P.amber}}>AI NPC</div>
        <div style={{fontSize: 46, color: P.muted, marginTop: 12}}>人物表达</div>
      </div>
    </ArchitectureCard>

    <div style={{position: 'absolute', left: 1310, top: 1128, width: 80, height: 5, background: P.line}}><div style={{width: `${flow * 100}%`, height: '100%', background: P.jade}}/></div>
    <div style={{position: 'absolute', left: 2450, top: 1128, width: 80, height: 5, background: P.line}}><div style={{width: `${flow * 100}%`, height: '100%', background: P.amber}}/></div>
  </Fade>;
};

const WorldCard: React.FC<{src: string; title: string; description: string; active: number; side: 'left' | 'right'}> = ({src, title, description, active, side}) => <div style={{position: 'relative', height: '100%', overflow: 'hidden', opacity: .52 + active * .48, transform: `translateX(${(1 - active) * (side === 'left' ? -38 : 38)}px)`}}>
  <ProjectShot src={src} dim={.54}/>
  <div style={{position: 'absolute', left: 70, bottom: 72}}>
    <div style={{fontFamily: serif, fontSize: 86, color: active > .72 ? P.jade : P.text}}>{title}</div>
    <div style={{fontSize: 46, color: P.muted, marginTop: 18}}>{description}</div>
  </div>
</div>;

const Packs: React.FC = () => {
  const frame = useCurrentFrame();
  const focus = interpolate(frame, [52, 132], [0, 1], clamp);
  return <Fade duration={240}>
    <div style={{position: 'absolute', left: 230, top: 745, width: 1250, fontFamily: serif, fontSize: 112, lineHeight: 1.36}}>同一套框架，<br/><span style={{color: P.jade}}>运行不同世界。</span></div>
    <div style={{position: 'absolute', right: 230, top: 390, width: 2160, height: 1130, display: 'grid', gridTemplateColumns: '1fr 1fr', borderRadius: 28, overflow: 'hidden', background: P.surface, border: `1px solid ${P.line}`, boxShadow: '0 34px 110px rgba(0,0,0,.4)'}}>
      <WorldCard src="tech/ai-dialogue.png" title="《天变邸抄》" description="灾后查证" active={1 - focus * .5} side="left"/>
      <WorldCard src="tech/fantu-gameplay.jpg" title="《凡途》" description="修仙抉择" active={.5 + focus * .5} side="right"/>
      <div style={{position: 'absolute', left: '50%', top: 0, bottom: 0, width: 2, background: P.line}}/>
    </div>
  </Fade>;
};

const OpenSource: React.FC = () => {
  const frame = useCurrentFrame();
  const repoIn = interpolate(frame, [0, 44], [0, 1], clamp);
  const platformsIn = interpolate(frame, [52, 112], [0, 1], clamp);
  return <Fade duration={300}>
    <div style={{position: 'absolute', left: 230, top: 720, width: 1450, fontFamily: serif, fontSize: 112, lineHeight: 1.4}}>
      代码已经开源，<br/><span style={{color: P.jade}}>欢迎把你的故事放进来。</span>
    </div>
    <div style={{position: 'absolute', right: 230, top: 390, width: 1940, height: 1110, display: 'grid', gridTemplateRows: '1fr 250px', gap: 32, opacity: repoIn, transform: `translateY(${(1 - repoIn) * 68}px)`}}>
      <div style={{borderRadius: 28, background: P.surface, border: `1px solid ${P.line}`, display: 'grid', gridTemplateColumns: '360px 1fr', alignItems: 'center', padding: '0 90px', gap: 74}}>
        <div style={{height: 270, width: 270, borderRadius: 150, background: P.text, display: 'grid', placeItems: 'center'}}><Logo src="tech/github.svg" height={156}/></div>
        <div><div style={{fontFamily: mono, fontSize: 46, color: P.muted}}>github.com/gqy20/narra</div><div style={{fontSize: 170, color: P.amber, fontWeight: 700, marginTop: 18}}>MIT</div></div>
      </div>
      <div style={{display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 32, opacity: platformsIn, transform: `translateY(${(1 - platformsIn) * 42}px)`}}>
        {['Windows', 'macOS'].map(platform => <div key={platform} style={{borderRadius: 22, background: P.surface2, border: `1px solid rgba(52,211,153,.34)`, display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 64px', fontSize: 48}}><span>{platform}</span><span style={{color: P.jade}}>可构建</span></div>)}
      </div>
    </div>
  </Fade>;
};

const Outro: React.FC = () => <Fade duration={150}>
  <div style={{position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', textAlign: 'center'}}>
    <div><div style={{fontFamily: serif, fontSize: 238, letterSpacing: 22}}>Narra</div><div style={{width: 1000, height: 4, background: P.jade, margin: '55px auto'}}/><div style={{fontSize: 64, color: P.muted}}>让故事成为可以运行的世界</div></div>
  </div>
</Fade>;

export const ArchitectureFilm: React.FC = () => <Shell>
  <Sequence from={0} durationInFrames={270}><Making/></Sequence>
  <Sequence from={270} durationInFrames={480}><Architecture/></Sequence>
  <Sequence from={750} durationInFrames={240}><Packs/></Sequence>
  <Sequence from={990} durationInFrames={300}><OpenSource/></Sequence>
  <Sequence from={1290} durationInFrames={150}><Outro/></Sequence>
</Shell>;
