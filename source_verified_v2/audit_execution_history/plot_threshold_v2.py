from pathlib import Path
import sys,csv,shutil
w=Path(__file__).parent;sys.path.insert(0,str(w/'revision/pylibs'))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
r=w/'audit_replay_threshold_station_20260918';out=r/'Figures';out.mkdir(exist_ok=True)
rows=list(csv.DictReader((r/'threshold/threshold_paired_bootstrap.csv').open()))
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'pdf.fonttype':42,'ps.fonttype':42})
fig,axes=plt.subplots(2,2,figsize=(7.2,6.5),layout='constrained')
for i,policy in enumerate(['accepted','strict']):
 for j,method in enumerate(['Stack','PhaseNet']):
  ax=axes[i,j];sel=[x for x in rows if x['Policy']==policy and x['Phase']=='S' and x['Comparison']==method+' Full3C minus Zonly' and float(x['quality_threshold'])==3]
  arr=np.array([[float(next(x for x in sel if float(x['peak_threshold'])==p and int(x['max_SP_seconds'])==s)['Delta']) for p in [.2,.3,.4]] for s in [20,30,40]])
  im=ax.imshow(arr,vmin=0,vmax=.4,cmap='YlGnBu',aspect='auto')
  for y in range(3):
   for x in range(3):ax.text(x,y,f'{arr[y,x]:.4f}',ha='center',va='center',color='white' if arr[y,x]>.24 else 'black',fontsize=12)
  ax.add_patch(Rectangle((.5,.5),1,1,fill=False,edgecolor='#ef8a17',linewidth=2.8))
  ax.set_xticks(range(3),['0.20','0.30','0.40']);ax.set_yticks(range(3),['20','30','40']);ax.set_xlabel('Peak threshold');ax.set_ylabel('Maximum S–P window (s)')
  ax.set_title(f'{chr(65+i*2+j)}  {method} | '+('accepted' if policy=='accepted' else 'detected only'),loc='left',fontweight='bold')
fig.colorbar(im,ax=axes,shrink=.72,label='S ΔF1 at ±100 ms (Full3C − Z-only)')
fig.suptitle('Decoder sensitivity at quality threshold 3',fontsize=14,fontweight='bold')
fig.supxlabel('Orange outline: retained primary setting.\nFixed fitted models; no threshold selection.',fontsize=10)
fig.savefig(out/'S7_threshold_sensitivity.png',dpi=600,bbox_inches='tight');fig.savefig(out/'S7_threshold_sensitivity.pdf',bbox_inches='tight')
plt.close(fig)
manual=list(csv.DictReader((w/'audit_no_training_20260918/sensitivity_paired_bootstrap_100ms.csv').open()))
subsets=['all_test','manual_both','sources_without_historical_train_val','manual_both_sources_without_historical_train_val']
labels=['All test\n330 records / 221 sources','Both arrivals manual\n287 records / 188 sources','No historical train/validation*\n26 records / 25 sources','Manual and no historical\ntrain/validation*\n20 records / 19 sources']
fig,ax=plt.subplots(figsize=(7.2,4.6))
for method,offset,color,label in [('Stack',-.10,'#2166a5','Stacker'),('PhaseNet',.10,'#b35825','PhaseNet-style')]:
 vals=[next(x for x in manual if x['subset']==sub and x['Policy']=='accepted' and x['Phase']=='S' and x['Comparison']==method+' Full3C minus Zonly') for sub in subsets]
 d=np.array([float(x['Delta']) for x in vals]);lo=np.array([float(x['CI_low']) for x in vals]);hi=np.array([float(x['CI_high']) for x in vals]);ax.errorbar(d,np.arange(4)+offset,xerr=[d-lo,hi-d],fmt='o',capsize=3,color=color,label=label,markersize=5)
ax.set_yticks(np.arange(4),labels);ax.invert_yaxis();ax.set_ylim(3.5,-.65);ax.axvline(0,color='#888',linestyle='--',linewidth=1);ax.set_xlim(-.12,.50);ax.set_xticks([-.1,0,.1,.2,.3,.4,.5]);ax.grid(axis='x',alpha=.18);ax.set_xlabel('Full3C minus Z-only S F1 at ±100 ms');ax.legend(loc='upper left',fontsize=10,framealpha=.9)
fig.subplots_adjust(left=.43,right=.98,top=.95,bottom=.26)
fig.text(.02,.095,'* These sources occurred in historical test data; no development-naive subset is established.',fontsize=10)
fig.text(.02,.045,'10,000 source-cluster draws; fixed fits and split. Exploratory, unadjusted intervals.',fontsize=10)
fig.savefig(out/'S6_roles_manual_sensitivity.png',dpi=600,bbox_inches='tight');fig.savefig(out/'S6_roles_manual_sensitivity.pdf',bbox_inches='tight')
print('Figures S6 and S7 ready')
