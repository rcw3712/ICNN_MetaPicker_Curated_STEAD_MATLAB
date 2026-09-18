function plan = trainingPlan40()
% Forty fits; a logistic invocation fits its P and S heads together.
id=strings(0,1); mode=id; kind=id; seed=[]; fold=[];
for m=["Full3C","Zonly"]
    for k=1:5
        for b=["CNN","TCN"]
            append(m,b,42,k);
        end
    end
    for b=["CNN","TCN"]; append(m,b,42,0); end
    variants="full15ch";
    if m=="Full3C"
        variants=[variants,"probonly12","waveonly3","nodilation"];
    end
    for v=variants
        for s=42:44; append(m,v,s,-1); end
    end
    if m=="Full3C"; append(m,"logistic",42,-1); end
end
plan=table(id,mode,kind,seed,fold);
assert(height(plan)==40 && numel(unique(id))==40);
    function append(m,k,s,f)
        id(end+1,1)=sprintf('%s_%s_fold%d_seed%d',m,k,f,s);
        mode(end+1,1)=m;kind(end+1,1)=k;seed(end+1,1)=s;fold(end+1,1)=f;
    end
end
