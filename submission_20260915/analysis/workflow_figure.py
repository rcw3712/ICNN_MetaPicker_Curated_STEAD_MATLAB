from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
O=Path(__file__).resolve().parents[1]/'regenerated';(O/'Figures').mkdir(parents=True,exist_ok=True)
fig,ax=plt.subplots(figsize=(8,5.1));ax.set(xlim=(0,10),ylim=(0,8));ax.axis('off')
boxes=[(.2,5.55,'Curated STEAD input','2234 records / 2114 sources\nE, N, Z; 100 Hz; 60 s'),(5.2,5.55,'Source-disjoint partition','Train 1480 / validation 317 / test 317 sources\nTest: 335 records; no source overlap'),(5.2,2.95,'Base models and OOF','STA/LTA, AIC, CNN, TCN\nCNN/TCN: eight input channels\nFive source folds + inner validation'),(.2,2.95,'Temporal meta-learner','12 probability + 3 waveform channels\nI-CNN; seeds 42, 43, 44\nFinal base/meta reuse outer validation'),(.2,.35,'Fixed arrival decoder','P maximum; S search P + 0.1â€“30 s\nDetected and uncertain accepted\nStrict sensitivity retained'),(5.2,.35,'Frozen test evaluation','F1 at 50, 100, 200 ms; accepted-pick MAE\nFull3C / Z-only and learner ablations\nThree-seed means; source-cluster intervals')]
for x,y,title,body in boxes:
 ax.add_patch(FancyBboxPatch((x,y),4.6,2.05,boxstyle='round,pad=0.04',facecolor='#f2f6f8',edgecolor='#547885',linewidth=1));ax.text(x+.17,y+1.72,title,fontsize=11,weight='bold',va='top');ax.text(x+.17,y+1.16,body,fontsize=8.5,va='top',linespacing=1.6)
for a,b in [((4.83,6.5),(5.15,6.5)),((7.5,5.45),(7.5,5.1)),((5.13,3.95),(4.86,3.95)),((2.5,2.87),(2.5,2.47)),((4.83,1.4),(5.15,1.4))]:ax.annotate('',xy=b,xytext=a,arrowprops={'arrowstyle':'->','color':'#34495e','lw':1.3})
# Connect OOF to meta in reading order; split feeds OOF by label rather than crossing boxes.
ax.text(5,7.87,'Source-grouped evaluation and temporal stacking',ha='center',fontsize=12,weight='bold')
fig.tight_layout();fig.savefig(O/'Figures/main1.png',dpi=600,bbox_inches='tight');fig.savefig(O/'Figures/main1.pdf',bbox_inches='tight')

