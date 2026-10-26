@echo off
echo =======================================
echo     Deploying Supabase Edge Functions
echo =======================================

cd /d "%~dp0"

:: We will use npx since Node.js is available on your machine
:: Adding --project-ref ensures it does not ask for project selection

set PROJECT_REF=bizikadaucsyevdoagmm

echo Deploying create-ad...
call npx supabase functions deploy create-ad --project-ref %PROJECT_REF%

echo Deploying ai-content-review...
call npx supabase functions deploy ai-content-review --project-ref %PROJECT_REF%

echo Deploying analyze-ad-image...
call npx supabase functions deploy analyze-ad-image --project-ref %PROJECT_REF%

echo Deploying create-payment...
call npx supabase functions deploy create-payment --project-ref %PROJECT_REF%

echo Deploying get-kyc-document...
call npx supabase functions deploy get-kyc-document --project-ref %PROJECT_REF%

echo Deploying notify-ad-status...
call npx supabase functions deploy notify-ad-status --project-ref %PROJECT_REF%

echo Deploying notify-watchlist-match...
call npx supabase functions deploy notify-watchlist-match --project-ref %PROJECT_REF%

echo Deploying payment-webhook...
call npx supabase functions deploy payment-webhook --project-ref %PROJECT_REF%

echo Deploying request-otp...
call npx supabase functions deploy request-otp --project-ref %PROJECT_REF%

echo Deploying submit-kyc-request...
call npx supabase functions deploy submit-kyc-request --project-ref %PROJECT_REF%

echo =======================================
echo        Deployment Complete!
echo =======================================
pause
