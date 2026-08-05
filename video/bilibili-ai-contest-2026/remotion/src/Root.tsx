import React from 'react';
import {Composition} from 'remotion';
import {ArchitectureFilm} from './ArchitectureFilm';
import {OpeningFilm} from './OpeningFilm';

export const NarraVideoRoot: React.FC = () => <>
  <Composition id="NarraOpening" component={OpeningFilm} durationInFrames={600} fps={30} width={3840} height={2160}/>
  <Composition id="NarraArchitecture" component={ArchitectureFilm} durationInFrames={1440} fps={30} width={3840} height={2160}/>
</>;
