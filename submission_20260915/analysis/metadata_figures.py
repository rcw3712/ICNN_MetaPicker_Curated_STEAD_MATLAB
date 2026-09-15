from pathlib import Path
import pandas as pd,numpy as np,h5py
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
P=Path(__file__).resolve().parents[1];F=P/'regenerated/Figures';F.mkdir(parents=True,exist_ok=True);S=P/'inputs';m=pd.read_excel(S/'metadata/metadata_master_2234_final.xlsx');plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'axes.spines.right':False,'axes.spines.top':False})

def save(fig,name):
 fig.tight_layout()
 for ext in ['png','pdf']:fig.savefig(F/(name+'.'+ext),dpi=600,bbox_inches='tight')
 plt.close(fig)
cols=['source_magnitude','source_distance_km','min_snr_db','sp_time_sec'];labels=['Magnitude','Distance (km)','Minimum component SNR (dB)','Sâ€“P time (s)'];fig,axs=plt.subplots(2,2,figsize=(8,6))
for ax,col,label in zip(axs.flat,cols,labels):ax.hist(m[col],bins=30,color='#318a97',edgecolor='white',linewidth=.5);ax.set(xlabel=label,ylabel='Records')
save(fig,'main2')
fig,axs=plt.subplots(2,2,figsize=(8,6));groups={name:set(pd.read_csv(S/'results/splits'/f'{name}_source_ids.csv').source_id) for name in ['train','val','test']}
assert not(groups['train']&groups['val'] or groups['train']&groups['test'] or groups['val']&groups['test'])
for ax,col,label in zip(axs.flat,cols,labels):
 bins=np.linspace(m[col].min(),m[col].max(),31)
 for name,color in zip(groups,['#318a97','#d47929','#777777']):ax.hist(m.loc[m.source_id.isin(groups[name]),col],bins=bins,density=True,histtype='step',color=color,label=name)
 ax.set(xlabel=label,ylabel='Density');ax.legend(fontsize=8)
fig.suptitle('Pairwise source overlap = 0',y=1.01);save(fig,'supp2')
x=pd.read_csv(P/'derived/example_test_tensor.csv').to_numpy()
r=m.set_index('event_id').loc['stead_event_00001'];t=np.arange(6000)/100;yp=np.exp(-(t-r.p_arrival_sec)**2/(2*.06**2));ys=np.exp(-(t-r.s_arrival_sec)**2/(2*.08**2));yp[abs(t-r.p_arrival_sec)>.24]=0;ys[abs(t-r.s_arrival_sec)>.32]=0;yn=1-np.maximum(yp,ys);fig,axs=plt.subplots(2,1,figsize=(8,4.5),sharex=True);axs[0].plot(t,x[:,14],lw=.7,color='#34495e');axs[0].set(ylabel='Conditioned Z',title='stead_event_00001')
for a,c,l in [(yp,'#1764ab','P target'),(ys,'#bd3030','S target'),(yn,'#777777','Noise target')]:axs[1].plot(t,a,color=c,label=l)
for ax in axs:
 ax.axvline(r.p_arrival_sec,color='#1764ab',ls='--');ax.axvline(r.s_arrival_sec,color='#bd3030',ls='--')
axs[1].set(xlabel='Time (s)',ylabel='Target probability');axs[1].legend(ncol=3);save(fig,'main3')
