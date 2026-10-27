from pathlib import Path
import sys

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle,FancyArrowPatch
p=Path(__file__).parent
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'pdf.fonttype':42})
fig,axs=plt.subplots(1,2,figsize=(9,4.1))
for j,ax in enumerate(axs):
 ax.set(xlim=(0,10),ylim=(0,10));ax.axis('off')
 ax.text(0,9.7,('A  Split by record','B  Split by earthquake source')[j],weight='bold',fontsize=11)
 ax.scatter([1],[6.5],marker='*',s=260,color='#343434');ax.text(1,5.6,'Same\nearthquake',ha='center',fontsize=9)
 for i,(lab,y) in enumerate(zip(['Station A','Station B','Station C'],[8,6.5,5])):
  ax.add_patch(FancyArrowPatch((1.5,6.5),(3.1,y),arrowstyle='->',mutation_scale=10,color='#777'))
  ax.scatter([3.5],[y],marker='^',s=75,color='#333');ax.text(4,y,lab,va='center',fontsize=9)
  is_test=j==0 and i==2;c='#B85C1C' if is_test else '#226D94'
  ax.add_patch(FancyArrowPatch((6.2,y),(7.1,y),arrowstyle='->',mutation_scale=10,color=c))
  ax.add_patch(Rectangle((7.3,y-.35),2,.7,facecolor=c,edgecolor=c));ax.text(8.3,y,'Test' if is_test else 'Train',ha='center',va='center',color='white',fontsize=9)
 ax.text(5,3.4,('Different files can share\nan earthquake across subsets.','All recordings of this earthquake\nremain in the same subset.')[j],ha='center',va='center',fontsize=10)
 ax.text(5,1.5,('Fails a source-disjoint\nevaluation requirement.','Test records must come\nfrom other earthquake sources.')[j],ha='center',va='center',fontsize=10,color='#343434')
fig.subplots_adjust(left=.03,right=.98,bottom=.03,top=.96,wspace=.13)
fig.savefig(p/'Figure1_source_separation.png',dpi=600,facecolor='white')
fig.savefig(p/'Figure1_source_separation.pdf',facecolor='white')
fig.savefig(p/'Figure1_preview.png',dpi=140,facecolor='white')
