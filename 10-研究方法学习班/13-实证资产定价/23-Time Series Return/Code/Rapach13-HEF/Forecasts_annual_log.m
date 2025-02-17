%%%%%%%%%%%%%%%%%%%%%%%%
% Forecasts_annual_log.m
%%%%%%%%%%%%%%%%%%%%%%%%

% Last modified: 07-02-2012

clear;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Loading data and defining variables, 1926-2010
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Equity premium

market_return=xlsread('Returns_handbook_data','Annual',...
    'p57:p141'); % S&P 500 VW return
r_f_lag=xlsread('Returns_handbook_data','Annual',...
    'k56:k140'); % risk-free rate, lagged (1925-2009)
equity_premium=log(1+market_return)-...
    log(1+r_f_lag); % log excess return

% Predictors

D=xlsread('Returns_handbook_data','Annual','c57:c141'); % dividends
SP500=xlsread('Returns_handbook_data','Annual',...
    'b57:b141'); % S&P 500 index
DP=log(D)-log(SP500); % log dividend-price ratio
SP500_lag=xlsread('Returns_handbook_data','Annual',...
    'b56:b140'); % S&P 500 index, lagged (1925-2009)
DY=log(D)-log(SP500_lag); % log dividend yield
E=xlsread('Returns_handbook_data','Annual','d57:d141'); % earnings
EP=log(E)-log(SP500); % log earnings-price ratio
DE=log(D)-log(E); % log dividend-payout ratio
SVAR=xlsread('Returns_handbook_data','Annual','o57:o141'); % volatility
BM=xlsread('Returns_handbook_data','Annual',...
    'e57:e141'); % book-to-market ratio
NTIS=xlsread('Returns_handbook_data','Annual',...
    'j57:j141'); % net equity issuing activity
TBL=xlsread('Returns_handbook_data','Annual',...
    'f57:f141'); % T-bill rate
LTY=xlsread('Returns_handbook_data','Annual',...
    'i57:i141'); % long-term government bond yield
LTR=xlsread('Returns_handbook_data','Annual',...
    'm57:m141'); % long-term government bond return
TMS=LTY-TBL; % term spread
AAA=xlsread('Returns_handbook_data','Annual',...
    'g57:g141'); % AAA-rated corporate bond yield
BAA=xlsread('Returns_handbook_data','Annual',...
    'h57:h141'); % BAA-rated corporate bond yield
DFY=BAA-AAA; % default yield spread
CORPR=xlsread('Returns_handbook_data','Annual',...
    'n57:n141'); % long-term corporate bond return
DFR=CORPR-LTR; % default return spread
INFL_lag=xlsread('Returns_handbook_data','Annual',...
    'l56:l140'); % inflation, lagged (1925-2009)
ECON=[DP DY EP DE SVAR BM NTIS TBL LTY LTR TMS DFY DFR INFL_lag];
ECON_sink=[DP DY EP SVAR BM NTIS TBL LTY LTR DFY DFR INFL_lag];

% Sum-of-the-parts variables

E_lag=xlsread('Returns_handbook_data','Annual',...
    'd56:d140'); % earnings, lagged (1925-2009)
E_growth=log(E)-log(E_lag); % earnings growth
DP_SOP=log(1+D./SP500); % log (1+D/P)
r_f=xlsread('Returns_handbook_data','Annual',...
    'k57:k141'); % risk-free rate
r_f=log(1+r_f); % log risk-free rate

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Estimating full-sample parameters for Campbell-Thompson restrictions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

beta_full=zeros(size(ECON,2),1);
T=size(equity_premium,1);
LHS=equity_premium(2:T);
for i=1:size(ECON,2);
    RHS_i=[ECON(1:T-1,i) ones(T-1,1)];
    results_i=ols(LHS,RHS_i);
    beta_full(i)=results_i.beta(1);
    disp(i); 
end;
beta_full(5)=1; % restricting SVAR slope coefficient to be positive

% NB: following Campbell and Thompson (2008) by using full-sample
% estimates as theoretical 'priors' (although we make sure that
% SVAR slope coefficient is positive)

%%%%%%%%%%%%%%%
% Preliminaries
%%%%%%%%%%%%%%%

Y=equity_premium;
T=size(Y,1);
N=size(ECON,2);
R=(1946-1926)+1; % in-sample period, 1926-1946
P_0=(1956-1946); % holdout out-of-sample period, 1947-1956
P=T-(R+P_0); % forecast evaluation period, 1957-2010
theta=0.75; % discound factor for DMSFE pooled forecast
r=1; % number of principal components
MA_SOP=20; % window size for SOP forecast

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Computing forecasts, 1947-2010 (includes holdout OOS period)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

FC_HA=zeros(P_0+P,1);
FC_ECON=zeros(P_0+P,N);
beta_ECON=zeros(P_0+P,N,2);
FC_ECON_CT=zeros(P_0+P,N);
omega_DMSFE=zeros(P_0+P,N);
FC_OTHER=zeros(P_0+P,5+size(theta,1));
FC_OTHER_CT=zeros(P_0+P,5+size(theta,1));
for t=1:P_0+P;
    FC_HA(t)=mean(Y(1:R+(t-1)));

    % Individual predictive regression forecasts

    X_t=ECON(1:R+(t-1)-1,:);
    Y_t=Y(2:R+(t-1));
    for i=1:N;
        results_t_i=ols(Y_t,[X_t(:,i) ones(R+(t-1)-1,1)]);
        FC_ECON(t,i)=[ECON(R+(t-1),i) 1]*results_t_i.beta;
        beta_ECON(t,i,1)=results_t_i.beta(1);
        beta_ECON(t,i,2)=results_t_i.bstd(1);
        if beta_full(i)>0;
            if results_t_i.beta(1)>0;
                FC_ECON_CT(t,i)=FC_ECON(t,i);
            elseif results_t_i.beta(1)<0;
                FC_ECON_CT(t,i)=FC_HA(t);
            end;
        elseif beta_full(i)<0;
            if results_t_i.beta(1)<0;
                FC_ECON_CT(t,i)=FC_ECON(t,i);
            elseif results_t_i.beta(1)>0;
                FC_ECON_CT(t,i)=FC_HA(t);
            end;
        end;
        if FC_ECON_CT(t,i)<0;
            FC_ECON_CT(t,i)=0;
        end;
    end;
    if t>P_0;

        % Kitchen sink forecast

        X_t_sink=ECON_sink(1:R+(t-1)-1,:);
        results_t_sink=ols(Y_t,[X_t_sink ones(R+(t-1)-1,1)]);
        FC_OTHER(t,1)=[ECON_sink(R+(t-1),:) 1]*results_t_sink.beta;
        if FC_OTHER(t,1)<0;
            FC_OTHER_CT(t,1)=0;
        else
            FC_OTHER_CT(t,1)=FC_OTHER(t,1);
        end;

        % SIC forecast

        j_max=3; % consider models with up to 3 predictors to save time
        SIC_t=[];
        for j=1:j_max;
            select_j=nchoosek(1:1:size(X_t_sink,2),j);
            for k=1:size(select_j,1);
                X_t_j_k=[X_t_sink(1:R+(t-1)-1,select_j(k,:)) ...
                    ones(R+(t-1)-1,1)];
                results_t_j_k=ols(Y_t,X_t_j_k);
                SIC_t_j_k=log(results_t_j_k.resid'*results_t_j_k.resid/...
                    size(Y_t,1))+log(size(Y_t,1))*size(X_t_j_k,2)/...
                    size(Y_t,1);
                FC_t_j_k=[ECON_sink(R+(t-1),select_j(k,:)) 1]*...
                    results_t_j_k.beta;
                SIC_t=[SIC_t ; SIC_t_j_k FC_t_j_k];
            end;
        end;
        [SIC_t_min,SIC_t_min_index]=min(SIC_t(:,1));
        FC_OTHER(t,2)=SIC_t(SIC_t_min_index,2);
        if FC_OTHER(t,2)<0;
            FC_OTHER_CT(t,2)=0;
        else
            FC_OTHER_CT(t,2)=FC_OTHER(t,2);
        end;

        % Pooled forecast: simple average

        FC_OTHER(t,3)=mean(FC_ECON(t,:),2);
        if FC_OTHER(t,3)<0;
            FC_OTHER_CT(t,3)=0;
        else
            FC_OTHER_CT(t,3)=FC_OTHER(t,3);
        end;

        % Pooled forecast: DMSFE

        powers_t=(t-2:-1:0)';
        m=sum((kron(ones(1,N),(theta*ones(t-1,1)).^powers_t)).*...
            ((kron(ones(1,N),Y(R+1:R+(t-1)))-FC_ECON(1:(t-1),:)).^2))';
        omega=(m.^(-1))/(sum(m.^(-1)));
        omega_DMSFE(t,:)=omega';
        FC_OTHER(t,4)=FC_ECON(t,:)*omega;
        if FC_OTHER(t,4)<0;
            FC_OTHER_CT(t,4)=0;
        else
            FC_OTHER_CT(t,4)=FC_OTHER(t,4);
        end;

        % Diffusion index forecast

        X_t_DI_standardize=zscore(ECON(1:R+(t-1),:));
        [Lambda_t F_t]=princomp(X_t_DI_standardize);
        results_t_DI=ols(Y_t,[F_t(1:end-1,1:r) ones(R+(t-1)-1,1)]);
        FC_OTHER(t,5)=[F_t(end,1:r) 1]*results_t_DI.beta;
        if FC_OTHER(t,5)<0;
            FC_OTHER_CT(t,5)=0;
        else
            FC_OTHER_CT(t,5)=FC_OTHER(t,5);
        end;

        % Sum-of-the-parts forecast

        FC_OTHER(t,6)=mean(E_growth(R+(t-1)-MA_SOP+1:R+(t-1)))+...
            DP_SOP(R+(t-1))-r_f(R+(t-1));
        if FC_OTHER(t,6)<0;
            FC_OTHER_CT(t,6)=0;
        else
            FC_OTHER_CT(t,6)=FC_OTHER(t,6);
        end;
    end;
    disp([t FC_HA(t) FC_OTHER(t,:)]); 
end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Forecast evaluation based on MSFE, 1957-2010
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

beta_ECON=beta_ECON(P_0+1:end,:,:);
actual=Y(R+P_0+1:end);
FC_HA=FC_HA(P_0+1:end);
FC_ECON=FC_ECON(P_0+1:end,:);
FC_ECON_CT=FC_ECON_CT(P_0+1:end,:);
FC_OTHER=FC_OTHER(P_0+1:end,:);
FC_OTHER_CT=FC_OTHER_CT(P_0+1:end,:);
omega_DMSFE=omega_DMSFE(P_0+1:end,:,:);
e_HA=actual-FC_HA;
e_ECON=kron(ones(1,size(FC_ECON,2)),actual)-FC_ECON;
e_ECON_CT=kron(ones(1,size(FC_ECON_CT,2)),actual)-FC_ECON_CT;
CSFE_HA=cumsum(e_HA.^2);
CSFE_ECON=cumsum(e_ECON.^2);
CSFE_ECON_CT=cumsum(e_ECON_CT.^2);
DCSFE_ECON=kron(ones(1,size(FC_ECON,2)),CSFE_HA)-CSFE_ECON;
DCSFE_ECON_CT=kron(ones(1,size(FC_ECON,2)),CSFE_HA)-CSFE_ECON_CT;
R2OS_ECON=zeros(size(FC_ECON,2),2);
R2OS_ECON_CT=zeros(size(FC_ECON_CT,2),2);
for i=1:size(R2OS_ECON,1);
    R2OS_ECON(i,1)=100*(1-(sum(e_ECON(:,i).^2)/sum(e_HA.^2)));
    f_i=e_HA.^2-(e_ECON(:,i).^2-(FC_HA-FC_ECON(:,i)).^2);
    results_i=nwest(f_i,ones(size(f_i,1),1),0);
    R2OS_ECON(i,2)=1-normcdf(results_i.tstat,0,1);
    R2OS_ECON_CT(i,1)=100*(1-(sum(e_ECON_CT(:,i).^2)/sum(e_HA.^2)));
    f_i=e_HA.^2-(e_ECON_CT(:,i).^2-(FC_HA-FC_ECON_CT(:,i)).^2);
    results_i=nwest(f_i,ones(size(f_i,1),1),0);
    R2OS_ECON_CT(i,2)=1-normcdf(results_i.tstat,0,1);
end;
e_OTHER=kron(ones(1,size(FC_OTHER,2)),actual)-FC_OTHER;
e_OTHER_CT=kron(ones(1,size(FC_OTHER_CT,2)),actual)-FC_OTHER_CT;
CSFE_OTHER=cumsum(e_OTHER.^2);
CSFE_OTHER_CT=cumsum(e_OTHER_CT.^2);
DCSFE_OTHER=kron(ones(1,size(FC_OTHER,2)),CSFE_HA)-CSFE_OTHER;
DCSFE_OTHER_CT=kron(ones(1,size(FC_OTHER_CT,2)),CSFE_HA)-CSFE_OTHER_CT;
R2OS_OTHER=zeros(size(FC_OTHER,2),2);
R2OS_OTHER_CT=zeros(size(FC_OTHER_CT,2),2);
for i=1:size(R2OS_OTHER,1);
    R2OS_OTHER(i,1)=100*(1-(sum(e_OTHER(:,i).^2)/sum(e_HA.^2)));
    f_i=e_HA.^2-(e_OTHER(:,i).^2-(FC_HA-FC_OTHER(:,i)).^2);
    results_i=nwest(f_i,ones(size(f_i,1),1),0);
    R2OS_OTHER(i,2)=1-normcdf(results_i.tstat,0,1);
    R2OS_OTHER_CT(i,1)=100*(1-(sum(e_OTHER_CT(:,i).^2)/sum(e_HA.^2)));
    f_i=e_HA.^2-(e_OTHER_CT(:,i).^2-(FC_HA-FC_OTHER_CT(:,i)).^2);
    results_i=nwest(f_i,ones(size(f_i,1),1),0);
    R2OS_OTHER_CT(i,2)=1-normcdf(results_i.tstat,0,1);
end;
%save('Forecasts_annual_log_store','actual','FC_HA','FC_ECON',...
%    'beta_ECON','FC_ECON_CT','FC_OTHER','FC_OTHER_CT','omega_DMSFE',...
%    'DCSFE_ECON','DCSFE_ECON_CT','DCSFE_OTHER','DCSFE_OTHER_CT',...
%    'R2OS_ECON','R2OS_ECON_CT','R2OS_OTHER','R2OS_OTHER_CT');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Writing results to spreadsheet
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%xlswrite('Returns_handbook_results',R2OS_ECON,...
%    'Annual','b4');
%xlswrite('Returns_handbook_results',R2OS_ECON_CT,...
%    'Annual','f4');
%xlswrite('Returns_handbook_results',R2OS_OTHER,...
%    'Annual','b19');
%xlswrite('Returns_handbook_results',R2OS_OTHER_CT,...
%    'Annual','f19');
