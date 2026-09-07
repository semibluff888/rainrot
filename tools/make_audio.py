"""Original deterministic sound design. No third party samples."""
from pathlib import Path
import wave
import numpy as np

OUT=Path(__file__).resolve().parents[1]/'assets'/'audio'
OUT.mkdir(parents=True,exist_ok=True)
SR=24000
rng=np.random.default_rng(9009)

def noise(n, smooth=1):
    a=rng.normal(0,1,n+smooth)
    return np.convolve(a,np.ones(smooth)/smooth,mode='valid')[:n]

def save(name, data, gain=.85, loop=False):
    data=np.asarray(data)
    if data.ndim==1: data=np.stack([data,np.roll(data,83)],axis=1)
    if not loop:
        fade=min(240,len(data)//4)
        data[:fade]*=np.linspace(0,1,fade)[:,None]
        data[-fade:]*=np.linspace(1,0,fade)[:,None]
    data=data/max(float(np.max(np.abs(data))),1e-5)*gain
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((data*32767).astype('<i2').tobytes())

t=np.arange(SR*24)/SR
n=len(t)
rain=.14*noise(n,3)+.24*noise(n,23)+.18*noise(n,90)
rain*=.8+.12*np.sin(2*np.pi*t/12)+.08*np.cos(2*np.pi*t/8)
save('rain',rain,.62,True)
drone=sum(np.sin(2*np.pi*f*t+p)*v for f,v,p in [(36,.5,0),(54,.2,.2),(72.125,.12,1),(108,.05,2)])
drone=drone*(.6+.4*np.sin(np.pi*t/24)**2)+noise(n,300)*1.3
save('roomtone',drone,.43,True)
music=np.zeros(n)
for f in [110,164.8125,220,261.625,329.625]:
    music+=np.sin(2*np.pi*f*t)*(.25+.1*np.sin(2*np.pi*t/12+f))*np.exp(-((t%8)/3))*.13
music+=noise(n,200)*.04
save('safe',music,.35,True)
threat=(np.sin(2*np.pi*43*t)+.3*np.sin(2*np.pi*86.125*t))*(.2+.8*np.sin(2*np.pi*t*1.5)**16)
threat+=noise(n,22)*.6
save('threat',threat,.6,True)
for k in range(4):
    t=np.arange(int(.42*SR))/SR
    a=(noise(len(t),5)*np.exp(-t*25)+np.sin(t*2*np.pi*(90+k*8))*np.exp(-t*40))
    a+=.25*noise(len(t),2)*np.exp(-((t-.12)/.024)**2)
    save('step'+str(k),a,.35)
t=np.arange(SR)/SR
save('shot',noise(len(t),2)*np.exp(-t*24)+np.sin(2*np.pi*65*t)*np.exp(-t*11),.95)
save('hit',noise(len(t),8)*np.exp(-t*15)+np.sin(2*np.pi*48*t)*np.exp(-t*12),.65)
save('click',noise(len(t),2)*np.exp(-t*110)+np.sin(2*np.pi*1700*t)*np.exp(-t*95),.3)
save('pickup',np.sin(2*np.pi*720*t)*np.exp(-t*9)+.4*np.sin(2*np.pi*1080*t)*np.exp(-t*7),.25)
t=np.arange(SR*3)/SR
save('door',noise(len(t),14)*np.exp(-t*3)+.4*np.sin(2*np.pi*(120*t-12*t*t))*np.exp(-t*1.6),.55)
save('breath',(noise(len(t),13)+.3*np.sin(2*np.pi*58*t))*(np.sin(np.pi*t/3)**3),.5)
t=np.arange(SR*5)/SR
save('sting',sum(np.sin(2*np.pi*f*t)*np.exp(-t*(1+f/1000)) for f in [43,57,79,331,351,369])+noise(len(t),50),.65)
save('thunder',noise(len(t),160)*np.exp(-t*.7)+.5*noise(len(t),25)*np.exp(-t*3),.8)
t=np.arange(SR*2)/SR
save('alarm',np.sin(2*np.pi*(420*t-30*np.cos(2*np.pi*t/2)))*(.5+.5*np.sin(np.pi*t)**2),.35,True)
def spatial(name, data, gain=.65):
    data=np.asarray(data, dtype=float)
    fade=min(360,len(data)//4)
    data[:fade]*=np.linspace(0,1,fade)
    data[-fade:]*=np.linspace(1,0,fade)
    data=data/max(float(np.max(np.abs(data))),1e-5)*gain
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((data*32767).astype('<i2').tobytes())

# Two identifiable spatial enemy voices. All components are synthesized here.
t=np.arange(int(SR*3.7))/SR
envelope=np.maximum(0,np.sin(np.pi*t/3.7))**2
gasp=.25+.75*(.5+.5*np.sin(t*7.3))**3
spatial('smily_breath',(noise(len(t),15)*.8+np.sin(2*np.pi*(47*t+.45*np.sin(t*5))))*envelope*gasp,.55)
t=np.arange(int(SR*.72))/SR
spatial('smily_step',noise(len(t),8)*np.exp(-t*12)+.38*noise(len(t),3)*np.exp(-((t-.26)/.18)**2)+.42*np.sin(2*np.pi*61*t)*np.exp(-t*20),.44)
t=np.arange(int(SR*.85))/SR
spatial('smily_alert',(np.sin(2*np.pi*(73*t+16*t*t))+.32*np.sin(2*np.pi*211*t)+noise(len(t),9)*.5)*np.sin(np.pi*t/.85)**2,.58)
t=np.arange(int(SR*.55))/SR
spatial('smily_strike',noise(len(t),7)*np.exp(-t*8)+np.sin(2*np.pi*49*t)*np.exp(-t*12),.63)
t=np.arange(int(SR*4.2))/SR
spatial('nurse_breath',(noise(len(t),29)*.9+.32*np.sin(2*np.pi*63*t)+.12*np.sin(2*np.pi*(174*t+2*np.sin(t*4))))*np.sin(np.pi*t/4.2)**3,.5)
t=np.arange(int(SR*.48))/SR
spatial('nurse_step',sum(np.sin(2*np.pi*f*t)*np.exp(-t*d)*v for f,d,v in [(1260,35,.3),(741,28,.4),(186,19,.45)])+noise(len(t),2)*np.exp(-t*55),.47)
t=np.arange(int(SR*1.0))/SR
joint=np.zeros(len(t))
for at in [.08,.23,.43,.7]:
    u=np.maximum(0,t-at)
    joint+=(t>=at)*(noise(len(t),5)+.5*np.sin(2*np.pi*289*u))*np.exp(-u*50)
spatial('nurse_joint',joint+.12*noise(len(t),21)*np.sin(np.pi*t)**2,.51)
t=np.arange(int(SR*.65))/SR
spatial('nurse_stab',noise(len(t),4)*np.exp(-((t-.11)/.08)**2)+.4*np.sin(2*np.pi*831*t)*np.exp(-t*17)+.5*np.sin(2*np.pi*58*t)*np.exp(-t*12),.63)
print('Generated',len(list(OUT.glob('*.wav'))),'original audio assets')
