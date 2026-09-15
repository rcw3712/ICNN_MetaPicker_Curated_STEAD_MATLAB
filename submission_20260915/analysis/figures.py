from pathlib import Path
import numpy as np,pandas as pd,h5py,json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy import stats
import os
P=Path(__file__).resolve().parents[1];O=P/'regenerated';O.mkdir(exist_ok=True);F=O/'Figures';F.mkdir(exist_ok=True)
R=P/'frozen';A=O
summ=pd.read_csv(A/'replacement_multiseed_summary.csv');runs=pd.read_csv(R/'multiseed_runs_clean.csv');meta=pd.read_excel(P/'inputs/metadata/metadata_master_2234_final.xlsx').set_index('event_id')
T={(mode,seed):pd.read_csv(R/mode/'evaluation'/f'full15ch_seed{seed}_predictions.csv') for mode in ['Full3C','Zonly'] for seed in [42,43,44]}
colors=['#087f8c','#d47929']; plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.spines.top':False,'axes.spines.right':False,'savefig.dpi':200})
def save(fig,name):fig.tight_layout();fig.savefig(F/(name+'.png'),dpi=600,bbox_inches='tight');fig.savefig(F/(name+'.pdf'),bbox_inches='tight');plt.close(fig)
def errors(t,p):
 e=1000*(t[p+'_pred_sec']-t[p+'_true_sec']);return e.where(t[p+'_status'].isin(['detected','uncertain']))
def f1(t,p,tol):
 e=errors(t,p);return 2*(e.abs()<=tol+1e-7).sum()/(len(t)+e.notna().sum())
# Bootstrap all tolerances, mean of per-seed F1, paired test sources.
clusters=sorted(T['Full3C',42].source_id.unique()); W=np.random.default_rng(42).multinomial(317,np.full(317,1/317),size=10000); boot=[]
for p in ['p','s']:
 for tol in [50,100,200]:
  points={};draws={}
  for mode in ['Full3C','Zonly']:
   xx=[]; yy=[]
   for seed in [42,43,44]:
    t=T[mode,seed];e=errors(t,p);z=pd.DataFrame({'source':t.source_id,'n':1,'a':e.notna().astype(int),'tp':(e.abs()<=tol+1e-7).astype(int)}).groupby('source').sum().reindex(clusters).to_numpy();xx.append(2*z[:,2].sum()/(z[:,0]+z[:,1]).sum());yy.append(2*(W@z[:,2])/(W@(z[:,0]+z[:,1])))
   points[mode]=np.mean(xx);draws[mode]=np.mean(yy,axis=0);lo,hi=np.quantile(draws[mode],[.025,.975]);boot.append([mode,p.upper(),tol,points[mode],lo,hi])
  lo,hi=np.quantile(draws['Full3C']-draws['Zonly'],[.025,.975]);boot.append(['Full3C - Zonly',p.upper(),tol,points['Full3C']-points['Zonly'],lo,hi])
pd.DataFrame(boot,columns=['Mode','Phase','Tolerance_ms','F1','Low','High']).to_csv(O/'bootstrap_all.csv',index=False)
# Channel statistics over explicitly identified held-out Full3C tensors (all335 x6000 samples).
example=pd.read_csv(P/'derived/example_test_tensor.csv').to_numpy()
# Descriptives seed42 and means across seeds separately.
desc=[]
for (mode,seed),t in T.items():
 for p in ['p','s']:
  e=errors(t,p).dropna().abs().to_numpy();desc.append(dict(Mode=mode,Seed=seed,Phase=p.upper(),N_accepted=len(e),N_strict=int((t[p+'_status']=='detected').sum()),MAE=np.mean(e),MedAE=np.median(e),RMSE=np.sqrt(np.mean(e**2)),P75=np.quantile(e,.75),P90=np.quantile(e,.9),P95=np.quantile(e,.95),P99=np.quantile(e,.99),Over500=100*np.mean(e>500),Over1000=100*np.mean(e>1000),Over2000=100*np.mean(e>2000)))
pd.DataFrame(desc).to_csv(O/'error_descriptives.csv',index=False)
# Main figure4 / supplementary5 current tensor first test record.
fig,axs=plt.subplots(5,1,figsize=(8,7),sharex=True);tt=np.arange(6000)/100;truth=T['Full3C',42].iloc[0]
for i in range(4):
 for j,c in enumerate(['#1764ab','#bd3030','#777777']):axs[i].plot(tt,example[:,3*i+j],color=c,lw=.8,label=['P','S','Noise'][j])
 axs[i].set_ylabel(['STA/LTA','AIC','CNN','TCN'][i]);axs[i].set_ylim(-.05,1.05)
for j in range(3):axs[4].plot(tt,example[:,12+j],lw=.6,label=['E','N','Z'][j])
for ax in axs:
 ax.axvline(truth.p_true_sec,color='#1764ab',ls='--');ax.axvline(truth.s_true_sec,color='#bd3030',ls='--');ax.legend(loc='upper right',ncol=3,fontsize=7)
axs[-1].set_xlabel('Time (s)');fig.suptitle('Held-out record '+truth.event_id,y=1.01);save(fig,'main4')
# F1 means/SD
def f1plot(name):
 fig,axs=plt.subplots(1,2,figsize=(8,3.4))
 for ax,p in zip(axs,['P','S']):
  for mode,c in zip(['Full3C','Zonly'],colors):
   d=summ[(summ.Mode==mode)&(summ.Variant=='full15ch')&(summ.Phase==p)].sort_values('Tolerance_ms');ax.errorbar(d.Tolerance_ms,d.F1_mean,yerr=d.F1_SD,marker='o',capsize=4,label=mode.replace('Zonly','Z-only'),color=c)
  ax.set(xlabel='Matching tolerance (ms)',ylabel='F1 (mean ± SD)',title=p+' phase',ylim=(0,1));ax.set_xticks([50,100,200]);ax.legend()
 save(fig,name)
f1plot('main5');f1plot('supp3')
# residuals
fig,axs=plt.subplots(2,2,figsize=(8,5.5))
for j,p in enumerate(['p','s']):
 for mode,c in zip(['Full3C','Zonly'],colors):
  e=errors(T[mode,42],p).dropna();axs[0,j].hist(e,bins=np.arange(-500,510,20),histtype='step',color=c,label=mode.replace('Zonly','Z-only'));a=np.sort(np.abs(e));axs[1,j].plot(a,np.arange(1,len(a)+1)/len(a),color=c,label=mode.replace('Zonly','Z-only'))
 axs[0,j].set(title=p.upper()+' residuals (central window)',xlabel='Predicted − true (ms)',ylabel='Accepted picks');axs[0,j].legend();axs[1,j].set(xlabel='Absolute error (ms)',ylabel='Empirical cumulative fraction',xscale='symlog');axs[1,j].legend()
save(fig,'main6')
fig,axs=plt.subplots(1,2,figsize=(8,3.6));t=T['Full3C',42]
for ax,p in zip(axs,['p','s']):
 mask=errors(t,p).notna();d=t[mask];sc=ax.scatter(d[p+'_true_sec'],d[p+'_pred_sec'],c=meta.loc[d.event_id,'min_snr_db'],s=14,cmap='viridis');ax.plot([0,60],[0,60],'k--',lw=.8);ax.set(xlabel='True time (s)',ylabel='Predicted time (s)',title=p.upper()+' phase');fig.colorbar(sc,ax=ax,label='Minimum component SNR (dB)')
save(fig,'main7')
fig,axs=plt.subplots(2,4,figsize=(10,5.5));attrs=['source_distance_km','source_magnitude','min_snr_db','sp_time_sec'];labels=['Distance (km)','Magnitude','Minimum SNR (dB)','S−P (s)']
for i,p in enumerate(['p','s']):
 e=errors(t,p)
 for ax,col,label in zip(axs[i],attrs,labels):
  x=meta.loc[t.event_id,col].to_numpy();m=e.notna().to_numpy();ax.scatter(x[m],e[m],s=8,alpha=.55);ax.axhline(0,color='gray',lw=.6);ax.axhline(100,color='gray',ls=':',lw=.6);ax.axhline(-100,color='gray',ls=':',lw=.6);ax.set(xlabel=label,ylabel=p.upper()+' residual (ms)');ax.set_yscale('symlog',linthresh=100)
save(fig,'main8')
fig,axs=plt.subplots(3,2,figsize=(8,7));strat=[]
for j,p in enumerate(['p','s']):
 for mode,c in zip(['Full3C','Zonly'],colors):
  d=T[mode,42];snr=meta.loc[d.event_id,'min_snr_db'].to_numpy(); vals=[]
  for lo,hi in [(10,20),(20,40),(40,np.inf)]:
   q=d[(snr>=lo)&(snr<hi)];e=errors(q,p);v=[f1(q,p,100),e.abs().mean(),e.notna().mean()];vals.append(v);strat.append([mode,p,len(q),lo,hi,*v])
  for i in range(3):axs[i,j].plot(range(3),np.array(vals)[:,i],'-o',color=c,label=mode.replace('Zonly','Z-only'));axs[i,j].set_xticks(range(3),['10–<20','20–<40','≥40']);axs[i,j].set(ylabel=['F1@100 ms','MAE (ms)','Accepted coverage'][i],xlabel='Minimum SNR (dB)',title=p.upper() if i==0 else '');axs[i,j].legend(fontsize=7)
save(fig,'main9');pd.DataFrame(strat,columns=['Mode','Phase','N','SNR_low','SNR_high','F1','MAE','Coverage']).to_csv(O/'snr_strata.csv',index=False)
fig,axs=plt.subplots(1,2,figsize=(8,3.6))
for ax,p in zip(axs,['p','s']):
 for k,(mode,c) in enumerate(zip(['Full3C','Zonly'],colors)):
  q=np.quantile(errors(T[mode,42],p).dropna().abs(),[.5,.75,.9,.95,.99]);ax.bar(np.arange(5)+(k-.5)*.35,q,.35,label=mode.replace('Zonly','Z-only'),color=c)
 ax.set_xticks(range(5),['50','75','90','95','99']);ax.set(xlabel='Percentile',ylabel='Absolute error (ms)',yscale='log',title=p.upper()+' phase');ax.legend()
save(fig,'main10')
fig,axs=plt.subplots(2,2,figsize=(8,5.5))
for i,p in enumerate(['p','s']):
 for k,(mode,c) in enumerate(zip(['Full3C','Zonly'],colors)):
  e=errors(T[mode,42],p).dropna().abs();axs[i,0].hist(e,bins=np.logspace(0,5,35),histtype='step',color=c,label=mode.replace('Zonly','Z-only'));axs[i,1].bar(np.arange(3)+(k-.5)*.35,[100*(e>v).mean() for v in [500,1000,2000]],.35,color=c,label=mode.replace('Zonly','Z-only'))
 axs[i,0].set(xscale='log',xlabel='Absolute error (ms)',ylabel='Accepted picks',title=p.upper()+' phase');axs[i,0].legend();axs[i,1].set_xticks(range(3),['>500','>1000','>2000']);axs[i,1].set(xlabel='Error threshold (ms)',ylabel='Outlier fraction (%)');axs[i,1].legend()
save(fig,'main11')
# Representative failures: deterministic largest P/S errors and first missing/uncertain S.
d=T['Full3C',42]; choices=[(errors(d,'p').abs().idxmax(),'Largest P error'),(errors(d,'s').abs().idxmax(),'Largest S error')]
for status in ['not_detected','uncertain']:
 ix=d.index[d.s_status==status]
 if len(ix):choices.append((ix[0],'S '+status.replace('_',' ')))
wave_dir=Path(os.environ.get('ICNN_WAVEFORM_DIR',str(P/'inputs/data/csv_stead_filtered')))
if wave_dir.is_dir():
 fig,axs=plt.subplots(len(choices),1,figsize=(8,2.15*len(choices)),squeeze=False)
 for ax,(ix,label) in zip(axs[:,0],choices):
  row=d.loc[ix];w=pd.read_csv(Path(os.environ.get('ICNN_WAVEFORM_DIR',str(P/'inputs/data/csv_stead_filtered')))/(row.event_id+'.csv'));x=w[['E','N','Z']].to_numpy();x=x/np.maximum(np.max(np.abs(x),axis=0),1e-10)
  for j in range(3):ax.plot(w.sec,x[:,j]+j*2,lw=.5,label=['E','N','Z'][j])
  for p,c in [('p','#1764ab'),('s','#bd3030')]:
   ax.axvline(row[p+'_true_sec'],color=c,ls='--',label=p.upper()+' true')
   if np.isfinite(row[p+'_pred_sec']):ax.axvline(row[p+'_pred_sec'],color=c,label=p.upper()+' predicted')
  ax.set(title=label+' | '+row.event_id,xlabel='Time (s)',yticks=[]);ax.legend(ncol=7,fontsize=6,loc='upper right')
 save(fig,'main12')
else:print('Figure 12 requires ICNN_WAVEFORM_DIR; skipped in lightweight mode.')
# Full failure inventory compact quantitative alternative to illegible waveform collage.
fig,axs=plt.subplots(2,1,figsize=(8,5.5))
for ax,p in zip(axs,['p','s']):
 e=errors(d,p);ids=e.abs().nlargest(20).index;ax.bar(range(len(ids)),e.loc[ids],color=colors[0]);ax.set_xticks(range(len(ids)),[d.loc[i,'event_id'].replace('stead_event_','') for i in ids],rotation=90,fontsize=7);ax.set(ylabel=p.upper()+' residual (ms)',xlabel='Event suffix (stead_event_)')
save(fig,'supp4')
# Training/validation history exported directly from final checkpoint.
hist=pd.read_csv(P/'derived/training_history.csv');val=pd.read_csv(P/'derived/validation_history.csv');print('history columns',hist.columns.tolist(),val.columns.tolist())
fig,axs=plt.subplots(2,1,figsize=(8,5.5));x=hist.iloc[:,0];loss=hist['TrainingLoss'] if 'TrainingLoss' in hist else hist['Loss'];axs[0].plot(x,loss,color='#a9cdd1',lw=.4,label='Training loss');axs[0].plot(x,loss.rolling(194,min_periods=1).mean(),color=colors[0],label='194-iteration moving mean');vc='ValidationLoss' if 'ValidationLoss' in val else 'Loss';axs[0].plot(val.iloc[:,0],val[vc],'o-',color=colors[1],ms=3,label='Validation loss');axs[0].set(ylabel='Loss');axs[0].legend();lc='LearnRate' if 'LearnRate' in hist else 'LearningRate';axs[1].plot(x,hist[lc],color=colors[0]);axs[1].set(xlabel='Iteration',ylabel='Learning rate');save(fig,'supp1')
print('generated',len(list(F.glob('*.png'))),'figures')
