function model = fitLogisticClean(X,Y)
% Exact full-data ridge objective; bounded temporary memory per record.
% Both phase heads still constitute ONE training-plan invocation.
assert(numel(X)==numel(Y)&&~isempty(X));
D=size(X{1},2);N=0;total=zeros(1,D);
for i=1:numel(X)
    a=double(X{i}(1:10:end,:));
    assert(size(a,2)==D && all(isfinite(a),'all'));
    N=N+size(a,1);total=total+sum(a,1);
end
assert(N>1);mu=total/N;ss=zeros(1,D);
for i=1:numel(X)
    a=double(X{i}(1:10:end,:));ss=ss+sum((a-mu).^2,1);
end
scale=sqrt(ss/(N-1));scale(scale<1e-8)=1;
lambda=.01;R=diag([ones(1,D),0]);W=zeros(D+1,2);iterations=zeros(1,2);
for ph=1:2
    w=zeros(D+1,1);converged=false;
    for it=1:100
        [old,g,h]=statistics(w,ph,true);
        fprintf('[LOGISTIC] phase %d iteration %d objective %.9g gradient %.3g\n',ph,it,old,norm(g,inf));
        if norm(g,inf)<1e-6;converged=true;break;end
        delta=h\g;step=1;
        while statistics(w-step*delta,ph,false)>old && step>1e-8;step=step/2;end
        assert(step>1e-8,'Logistic line search failed.');w=w-step*delta;
    end
    assert(converged,'Logistic baseline did not converge; do not report it.');
    W(:,ph)=w;iterations(ph)=it;
end
model=struct('kind',"logistic",'mu',mu,'scale',scale,'W',W(1:end-1,:), ...
    'b',W(end,:),'iterations',iterations,'lambda',lambda,'stride',10);
    function [f,g,h]=statistics(w,phase,derivatives)
        f=0;g=zeros(D+1,1);h=zeros(D+1);
        for record=1:numel(X)
            a=double(X{record}(1:10:end,:));
            a=[(a-mu)./scale,ones(size(a,1),1)];
            y=double(Y{record}(1:10:end,phase)>.3);
            assert(size(a,1)==numel(y));z=a*w;
            f=f+sum(max(z,0)-y.*z+log1p(exp(-abs(z))));
            if derivatives
                p=1./(1+exp(-max(-60,min(60,z))));
                g=g+a'*(p-y);
                h=h+a'*(a.*max(p.*(1-p),1e-10));
            end
        end
        f=f/N+.5*lambda*(w'*R*w);
        if derivatives
            g=g/N+lambda*R*w;
            h=h/N+lambda*R+eye(D+1)*1e-10;
        end
    end
end