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

echo Deploying create-payment...
call npx supabase functions deploy create-payment --project-ref %PROJECT_REF%

echo Deploying dispatch-notifications...
call npx supabase functions deploy dispatch-notifications --project-ref %PROJECT_REF%

echo Deploying purge-deleted-accounts...
call npx supabase functions deploy purge-deleted-accounts --project-ref %PROJECT_REF%

echo Deploying purge-kyc-documents...
call npx supabase functions deploy purge-kyc-documents --project-ref %PROJECT_REF%

echo Deploying payment-webhook...
call npx supabase functions deploy payment-webhook --project-ref %PROJECT_REF%

echo Deploying send-sms-hook...
call npx supabase functions deploy send-sms-hook --no-verify-jwt --project-ref %PROJECT_REF%

echo Deploying submit-kyc-request...
call npx supabase functions deploy submit-kyc-request --project-ref %PROJECT_REF%

echo =======================================
echo        Deployment Complete!
echo =======================================
pause
