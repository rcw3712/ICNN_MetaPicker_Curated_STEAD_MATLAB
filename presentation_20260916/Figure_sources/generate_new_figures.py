from pathlib import Path
import sys,csv,statistics,shutil,copy,json
w=Path(__file__).parent
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
out=w/'generated';figdir=out;sources=out;qa=out
for p in [out,figdir,sources,qa]:p.mkdir(exist_ok=True)
a=w;rows=list(csv.DictReader(open(a/'recomputed_metrics.csv')))
rows=[x for x in rows if x['Policy']=='accepted' and x['Tolerance_ms']=='100']
summary=list(csv.DictReader(open(a/'summary.csv')))
plt.rcParams.update({'font.family':'Arial','font.size':9,'axes.labelsize':9,'axes.titlesize':10,'legend.fontsize':8,'pdf.fonttype':42,'ps.fonttype':42,'axes.spines.top':False,'axes.spines.right':False})
colors=['#087F8C','#D47929'];modes=['Full3C','Zonly'];methods=['Stack','PhaseNetMatched']
def vals(method,mode,phase,b=None):return [float(x['F1']) for x in rows if x['Method']==method and x['Mode']==mode and x['Phase']==phase and (b is None or x['BaseSeed']==str(b))]
def savenew(fig,num):
 fig.savefig(sources/f'Figure_{num}.pdf');fig.savefig(sources/f'Figure_{num}.png',dpi=1000);plt.close(fig)
fig,axs=plt.subplots(1,2,figsize=(190/25.4,95/25.4));fig.subplots_adjust(left=.09,right=.98,bottom=.20,top=.82,wspace=.27)
for ax,phase,label in zip(axs,['P','S'],['a','b']):
 for j,method in enumerate(methods):
  for k,mode in enumerate(modes):
   x=k+(j-.5)*.28
   v=[statistics.mean(vals(method,mode,phase,b)) for b in [42,43,44]]
   mean=statistics.mean(v);sd=statistics.stdev(v)
   ax.bar(x,mean,width=.25,color=colors[j],alpha=.78,zorder=2)
   ax.errorbar(x,mean,yerr=sd,color='#222222',capsize=3,lw=1,zorder=4)
   ax.scatter([x-.055,x,x+.055],v,color='white',edgecolor='#222222',s=18,lw=.65,zorder=5)
   ax.text(x,mean+sd+.035,f'{mean:.4f}',ha='center',fontsize=8)
 ax.set(xticks=[0,1],xticklabels=['Full3C','Z-only'],ylim=(0,1.09),yticks=[0,.2,.4,.6,.8,1],ylabel='F1 at ±100 ms',title=f'({label}) {phase} phase')
 ax.grid(axis='y',alpha=.18,zorder=0);ax.set_axisbelow(True)
fig.legend(handles=[Line2D([0],[0],color=c,lw=7,label=l) for c,l in zip(colors,['Stacker','PhaseNet-style'])],loc='upper center',ncol=2,frameon=False,bbox_to_anchor=(.54,.99))
savenew(fig,11)
fig,axs=plt.subplots(1,2,figsize=(190/25.4,100/25.4));fig.subplots_adjust(left=.105,right=.98,bottom=.20,top=.80,wspace=.30)
for ax,phase,label in zip(axs,['P','S'],['a','b']):
 for j,mode in enumerate(modes):
  means=[]
  for k,b in enumerate([42,43,44]):
   v=vals('Stack',mode,phase,b);means.append(statistics.mean(v));x=k+(j-.5)*.20
   for m,marker in enumerate(['o','s','^']):ax.scatter(x+(m-1)*.045,v[m],marker=marker,s=32,facecolors='white',edgecolors=colors[j],linewidths=1,zorder=3)
   ax.scatter(x,statistics.mean(v),marker='D',s=36,color=colors[j],edgecolor='white',linewidth=.5,zorder=4)
  ax.plot([k+(j-.5)*.20 for k in range(3)],means,color=colors[j],lw=.8,alpha=.65,zorder=2)
 ax.set(xticks=[0,1,2],xticklabels=['42','43','44'],xlabel='CNN/TCN base seed',ylabel='F1 at ±100 ms',title=f'({label}) {phase} phase')
 ax.set_ylim((.84,.90) if phase=='P' else (.30,.62));ax.grid(axis='y',alpha=.2)
handles=[Line2D([0],[0],color=c,lw=2,label=l) for c,l in zip(colors,['Full3C','Z-only'])]+[Line2D([0],[0],color='#555555',marker=m,markerfacecolor='white',linestyle='None',label=f'Meta {s}') for m,s in zip(['o','s','^'],[42,43,44])]+[Line2D([0],[0],color='#555555',marker='D',linestyle='None',label='Meta mean')]
fig.legend(handles=handles,loc='upper center',ncol=3,frameon=False,bbox_to_anchor=(.55,1.01),columnspacing=1.6)
savenew(fig,12)
