require 'spec_helper'
require 'actions/domain_delete_shared_org'
require 'messages/domain_delete_shared_org_message'

module VCAP::CloudController
  RSpec.describe DomainDeleteSharedOrg do
    subject { DomainDeleteSharedOrg }

    describe '#delete' do
      context 'when the domain is unscoped' do
        let(:domain) { SharedDomain.make }
        let(:shared_org1) { Organization.make }

        it 'raises an error' do
          expect {
            subject.delete(domain: domain, shared_organization: shared_org1)
          }.to raise_error(DomainDeleteSharedOrg::Error)
        end
      end

      context 'when the org is the owning org' do
        let(:shared_org1) { Organization.make }
        let(:domain) { PrivateDomain.make(owning_organization: shared_org1) }

        it 'raises an error' do
          expect {
            subject.delete(domain: domain, shared_organization: shared_org1)
          }.to raise_error(DomainDeleteSharedOrg::Error)
        end
      end

      context 'when unsharing a private domain not shared with org' do
        let(:domain) { PrivateDomain.make }
        let(:shared_org1) { Organization.make }

        it 'deletes shared orgs for private domain' do
          expect {
            subject.delete(domain: domain, shared_organization: shared_org1)
          }.to raise_error(DomainDeleteSharedOrg::Error)
        end
      end

      context 'when unsharing a shared private domain' do
        let(:domain) { PrivateDomain.make }
        let(:shared_org1) { Organization.make }

        before do
          domain.add_shared_organization(shared_org1)
        end

        it 'deletes shared orgs for private domain' do
          subject.delete(domain: domain, shared_organization: shared_org1)
          domain.reload
          expect(domain.shared_organizations.length).to be(0)
        end
      end
    end
  end
end
