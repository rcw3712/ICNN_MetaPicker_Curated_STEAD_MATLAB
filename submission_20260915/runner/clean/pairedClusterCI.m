function ci = pairedClusterCI(a,b,nBoot,seed,includeUncertain)
if nargin<5;includeUncertain=true;end
assert(numel(unique(a.event_id))==height(a)&&numel(unique(b.event_id))==height(b));
[ok,j]=ismember(a.event_id,b.event_id);assert(all(ok)&&height(a)==height(b));b=b(j,:);
assert(isequal(a.source_id,b.source_id));
assert(max(abs(a.p_true_sec-b.p_true_sec))<1e-9 && max(abs(a.s_true_sec-b.s_true_sec))<1e-9);
u=unique(a.source_id);[~,g]=ismember(a.source_id,u);K=numel(u);
r=RandStream('mt19937ar','Seed',seed); rows=cell(0,1);
for ph=["p","s"]
    ea=abs(1000*(a.(ph+"_pred_sec")-a.(ph+"_true_sec")));
    eb=abs(1000*(b.(ph+"_pred_sec")-b.(ph+"_true_sec")));
    sa=string(a.(ph+"_status"));sb=string(b.(ph+"_status"));
    da=isfinite(ea)&(sa=="detected"|(includeUncertain&sa=="uncertain"));
    db=isfinite(eb)&(sb=="detected"|(includeUncertain&sb=="uncertain"));
    for tol=[50 100 200]
        counts=[accumarray(g,1,[K 1]),accumarray(g,double(da),[K 1]), ...
            accumarray(g,double(db),[K 1]),accumarray(g,double(da&ea<=tol+1e-7),[K 1]), ...
            accumarray(g,double(db&eb<=tol+1e-7),[K 1])];
        draws=zeros(nBoot,3);
        for k=1:nBoot
            total=sum(counts(randi(r,K,K,1),:),1);
            fa=2*total(4)/max(1,total(1)+total(2));fb=2*total(5)/max(1,total(1)+total(3));
            draws(k,:)=[fa fb fa-fb];
        end
        total=sum(counts,1);fa=2*total(4)/(total(1)+total(2));fb=2*total(5)/(total(1)+total(3));
        q=prctile(draws,[2.5 97.5]);
        rows{end+1,1}=table(upper(ph),tol,fa,fb,fa-fb,q(1,1),q(2,1),q(1,2),q(2,2),q(1,3),q(2,3), ...
            'VariableNames',{'Phase','Tolerance_ms','F1_A','F1_B','Delta','A_low','A_high','B_low','B_high','Delta_low','Delta_high'}); %#ok<AGROW>
    end
end
ci=vertcat(rows{:});
end
