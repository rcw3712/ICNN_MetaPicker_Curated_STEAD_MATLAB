from pathlib import Path
import sys,h5py,numpy as np,pandas as pd
out=Path(sys.argv[2]) if len(sys.argv)>2 else Path.cwd();out.mkdir(exist_ok=True)
mins=np.full(15,np.inf);maxs=-mins;total=np.zeros(15);sq=np.zeros(15);n=0;nan=np.zeros(15,int);inf=nan.copy()
with h5py.File(sys.argv[1]) as h:
 for i,ref in enumerate(h['T'][0]):
  x=h[ref][()].astype(float);assert x.shape==(15,6000)
  mins=np.minimum(mins,x.min(axis=1));maxs=np.maximum(maxs,x.max(axis=1));total+=x.sum(axis=1);sq+=(x*x).sum(axis=1);n+=x.shape[1];nan+=np.isnan(x).sum(axis=1);inf+=np.isinf(x).sum(axis=1)
  if i==0:pd.DataFrame(x.T).to_csv(out/'example_test_tensor.csv',index=False)
assert n==335*6000
names=[f'{p}_{m}' for m in ['STA','AIC','CNN','TCN'] for p in ['P','S','Noise']]+['E conditioned','N conditioned','Z conditioned']
pd.DataFrame({'Channel':np.arange(1,16),'Feature':names,'Minimum':mins,'Maximum':maxs,'Mean':total/n,'SD':np.sqrt((sq-total**2/n)/(n-1)),'NaN':nan,'Inf':inf}).to_csv(out/'tensor_stats.csv',index=False)
print('Computed statistics over',n,'time samples per channel')
